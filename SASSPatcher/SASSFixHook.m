#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/log.h>

static NSString* SASSFixLegacyScope = @"service::kdc.xboxlive.com::MBI_SSL";
static NSString* SASSFixModernScope = @"XboxLive.signin XboxLive.offline_access";
static NSString* SASSFixLastXBL3Auth;

static void SASSFixLog(NSString* format, ...) {
    va_list args;
    va_start(args, format);
    NSString* message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
    va_end(args);

    if (@available(iOS 10.0, *)) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[SASSFix] %{public}@", message);
    } else {
        NSLog(@"[SASSFix] %@", message);
    }
}

static NSString* SASSFixRequestLabel(NSURLRequest* request) {
    NSURL* url = [request URL];
    NSString* host = [[url host] lowercaseString] ?: @"(no-host)";
    NSString* path = [url path];
    NSString* query = [host isEqualToString:@"profile.xboxlive.com"] || [host isEqualToString:@"achievements.xboxlive.com"] ? [url query] : nil;
    return [NSString stringWithFormat:@"%@ %@%@%@", [request HTTPMethod] ?: @"GET", host, [path length] ? path : @"/", [query length] ? [@"?" stringByAppendingString:query] : @""];
}

static NSData* SASSFixHTTP(NSUInteger status, NSURL* url, NSData* data, NSString* contentType, NSURLResponse** response) {
    if (response) {
        NSDictionary* headers = contentType ? @{@"Cache-Control": @"no-store", @"Content-Type": contentType} : @{@"Cache-Control": @"no-store"};
        *response = [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:headers] autorelease];
    }
    return data ?: [NSData data];
}

static void SASSFixFinish(NSURLProtocol* protocol, NSURLResponse* response, NSData* data) {
    [[protocol client] URLProtocol:protocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if ([data length]) {
        [[protocol client] URLProtocol:protocol didLoadData:data];
    }
    [[protocol client] URLProtocolDidFinishLoading:protocol];
}

static NSString* SASSFixXMLText(NSString* xml, NSString* name) {
    NSString* pattern = [NSString stringWithFormat:@"<(?:[A-Za-z0-9_.-]+:)?%@(?:\\s[^>]*)?>(.*?)</(?:[A-Za-z0-9_.-]+:)?%@>", name, name];
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    NSTextCheckingResult* match = [regex firstMatchInString:xml options:0 range:NSMakeRange(0, [xml length])];
    return match ? [[xml substringWithRange:[match rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
}

static NSString* SASSFixEscapeXML(NSString* value) {
    NSMutableString* escaped = [[value mutableCopy] autorelease];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0, [escaped length])];
    return escaped;
}

static NSDictionary* SASSFixPostJSON(NSString* url, NSDictionary* payload) {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"1" forHTTPHeaderField:@"x-xbl-contract-version"];

    NSURLResponse* response = nil; NSError* error = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse*)response statusCode] : 0;
    if (!data || error || status >= 400) {
        SASSFixLog(@"auth POST %@ failed status=%ld bytes=%lu error=%@", url, (long)status, (unsigned long)[data length], error);
        return nil;
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
        SASSFixLog(@"auth POST %@ returned non-object JSON status=%ld bytes=%lu", url, (long)status, (unsigned long)[data length]);
        return nil;
    }
    SASSFixLog(@"auth POST %@ succeeded status=%ld bytes=%lu", url, (long)status, (unsigned long)[data length]);
    return json;
}

static NSString* SASSFixUserToken(NSString* msaAccessToken) {
    NSArray* tickets = @[[@"d=" stringByAppendingString:msaAccessToken], msaAccessToken, [@"t=" stringByAppendingString:msaAccessToken]];
    for (NSUInteger i = 0; i < [tickets count]; i++) {
        SASSFixLog(@"requesting Xbox user token variant %lu of %lu", (unsigned long)(i + 1), (unsigned long)[tickets count]);
        NSString* ticket = [tickets objectAtIndex:i];
        NSDictionary* json = SASSFixPostJSON(@"https://user.auth.xboxlive.com/user/authenticate", @{
            @"RelyingParty": @"http://auth.xboxlive.com",
            @"TokenType": @"JWT",
            @"Properties": @{
                @"AuthMethod": @"RPS",
                @"SiteName": @"user.auth.xboxlive.com",
                @"RpsTicket": ticket,
            },
        });
        NSString* token = [json objectForKey:@"Token"];
        if (token) {
            SASSFixLog(@"Xbox user token exchange succeeded with variant %lu", (unsigned long)(i + 1));
            return token;
        }
    }
    SASSFixLog(@"Xbox user token exchange failed for all variants");
    return nil;
}

static NSData* SASSFixActiveAuthResponse(NSURLRequest* request, NSURLResponse** response) {
    NSString* auth = [request valueForHTTPHeaderField:@"Authorization"] ?: @"";
    NSRange marker = [auth rangeOfString:@"t="];
    if (marker.location == NSNotFound) {
        SASSFixLog(@"activeauth missing MSA token; returning synthetic HTTP 401");
        return SASSFixHTTP(401, [request URL], nil, nil, response);
    }

    NSUInteger start = NSMaxRange(marker), end = start;
    while (end < [auth length]) {
        unichar ch = [auth characterAtIndex:end];
        if (ch == ',' || [[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch]) {
            break;
        }
        end++;
    }
    NSString* msaAccessToken = [[auth substringWithRange:NSMakeRange(start, end - start)] stringByRemovingPercentEncoding] ?: [auth substringWithRange:NSMakeRange(start, end - start)];
    NSString* requestXML = [[[NSString alloc] initWithData:([request HTTPBody] ?: [NSData data]) encoding:NSUTF8StringEncoding] autorelease] ?: @"";

    SASSFixLog(@"activeauth extracted MSA token; starting Xbox auth exchange");
    NSString* userToken = SASSFixUserToken(msaAccessToken);
    NSString* relyingParty = @"http://xboxlive.com";
    NSRegularExpression* addressRegex = [NSRegularExpression regularExpressionWithPattern:@"<(?:[A-Za-z0-9_.-]+:)?Address[^>]*>(.*?)</(?:[A-Za-z0-9_.-]+:)?Address>" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    for (NSTextCheckingResult* match in [addressRegex matchesInString:requestXML options:0 range:NSMakeRange(0, [requestXML length])]) {
        NSString* address = [requestXML substringWithRange:[match rangeAtIndex:1]];
        if ([address rangeOfString:@"xboxlive.com"].location != NSNotFound) {
            relyingParty = address;
            break;
        }
    }
    if (userToken) {
        SASSFixLog(@"activeauth requesting XSTS for relying party %@", relyingParty);
    }
    NSDictionary* xsts = userToken ? SASSFixPostJSON(@"https://xsts.auth.xboxlive.com/xsts/authorize", @{
        @"RelyingParty": relyingParty,
        @"TokenType": @"JWT",
        @"Properties": @{
            @"SandboxId": @"RETAIL",
            @"UserTokens": @[ userToken ],
        },
    }) : nil;
    NSDictionary* claims = [xsts objectForKey:@"DisplayClaims"];
    NSArray* xui = [claims objectForKey:@"xui"];
    NSDictionary* first = [xui count] ? [xui objectAtIndex:0] : nil;
    NSString* token = [xsts objectForKey:@"Token"];
    NSString* xbl3 = token ? [NSString stringWithFormat:@"XBL3.0 x=%@;%@", [first objectForKey:@"uhs"] ?: @"", token] : nil;
    if (!xbl3) {
        SASSFixLog(@"activeauth XBL3 exchange failed; returning synthetic HTTP 502");
        return SASSFixHTTP(502, [request URL], nil, nil, response);
    }

    [SASSFixLastXBL3Auth release];
    SASSFixLastXBL3Auth = [xbl3 copy];
    SASSFixLog(@"activeauth cached XBL3 authorization header");

    NSDate* now = [NSDate date];
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    NSString* issue = [xsts objectForKey:@"IssueInstant"] ?: [dateFormatter stringFromDate:now];
    NSString* expires = [xsts objectForKey:@"NotAfter"] ?: [dateFormatter stringFromDate:[now dateByAddingTimeInterval:12 * 60 * 60]];
    NSString* messageID = SASSFixXMLText(requestXML, @"MessageID");
    NSString* tokenType = SASSFixXMLText(requestXML, @"TokenType");
    if (![messageID length])
        messageID = [@"urn:uuid:" stringByAppendingString:[[NSUUID UUID] UUIDString]];
    if (![tokenType length])
        tokenType = @"http://docs.oasis-open.org/wss/oasis-wss-saml-token-profile-1.1#SAMLV2.0";

    NSString* body = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        "<s:Envelope xmlns:s=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:a=\"http://www.w3.org/2005/08/addressing\" xmlns:u=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\">"
        "<s:Header><a:Action s:mustUnderstand=\"1\">http://docs.oasis-open.org/ws-sx/ws-trust/200512/RSTRC/IssueFinal</a:Action><a:RelatesTo>%@</a:RelatesTo></s:Header>"
        "<s:Body><trust:RequestSecurityTokenResponseCollection xmlns:trust=\"http://docs.oasis-open.org/ws-sx/ws-trust/200512\"><trust:RequestSecurityTokenResponse>"
        "<trust:TokenType>%@</trust:TokenType><trust:Lifetime><u:Created>%@</u:Created><u:Expires>%@</u:Expires></trust:Lifetime>"
        "<trust:RequestedSecurityToken><wsse:BinarySecurityToken xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\" EncodingType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary\" ValueType=\"urn:xboxlive:jwt\">%@</wsse:BinarySecurityToken></trust:RequestedSecurityToken>"
        "</trust:RequestSecurityTokenResponse></trust:RequestSecurityTokenResponseCollection></s:Body></s:Envelope>",
        SASSFixEscapeXML(messageID), SASSFixEscapeXML(tokenType), SASSFixEscapeXML(issue), SASSFixEscapeXML(expires), SASSFixEscapeXML([xsts objectForKey:@"Token"])];

    SASSFixLog(@"activeauth returned XBL3 SOAP response; returning synthetic HTTP 200");
    return SASSFixHTTP(200, [request URL], [body dataUsingEncoding:NSUTF8StringEncoding], @"application/soap+xml; charset=utf-8", response);
}

static NSURLRequest* SASSFixPreparedRequest(NSURLRequest* request) {
    NSURL* url = [request URL];
    NSString* host = [[url host] lowercaseString];
    NSString* path = [url path] ?: @"";
    NSMutableURLRequest* mutable = [[request mutableCopy] autorelease];

    if ([host isEqualToString:@"login.live.com"]) {
        if ([path isEqualToString:@"/oauth20_token.srf"] && [[request HTTPMethod] isEqualToString:@"POST"] && [request HTTPBody]) {
            NSString* body = [[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease];
            if (body) {
                NSString* rewritten = [[body stringByReplacingOccurrencesOfString:@"service%3A%3Akdc.xboxlive.com%3A%3AMBI_SSL" withString:@"XboxLive.signin%20XboxLive.offline_access"] stringByReplacingOccurrencesOfString:SASSFixLegacyScope withString:SASSFixModernScope];
                if (![rewritten isEqualToString:body]) {
                    [mutable setHTTPBody:[rewritten dataUsingEncoding:NSUTF8StringEncoding]];
                    [mutable setValue:nil forHTTPHeaderField:@"Content-Length"];
                    SASSFixLog(@"rewrote login.live.com token scope");
                } else {
                    SASSFixLog(@"login.live.com token scope unchanged; legacy scope not found");
                }
            } else {
                SASSFixLog(@"login.live.com token scope unchanged; non-UTF8 body");
            }
        } else if ([path isEqualToString:@"/oauth20_authorize.srf"] && [[request HTTPMethod] isEqualToString:@"GET"]) {
            NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSMutableArray* items = [[components.queryItems mutableCopy] autorelease];
            BOOL rewritten = NO;
            for (NSUInteger i = 0; i < [items count]; i++) {
                NSURLQueryItem* item = [items objectAtIndex:i];
                if ([item.name isEqualToString:@"scope"] && [item.value isEqualToString:SASSFixLegacyScope]) {
                    [items replaceObjectAtIndex:i withObject:[NSURLQueryItem queryItemWithName:@"scope" value:SASSFixModernScope]];
                    components.queryItems = items;
                    [mutable setURL:[components URL]];
                    SASSFixLog(@"rewrote login.live.com authorize scope");
                    rewritten = YES;
                    break;
                }
            }
            if (!rewritten) {
                SASSFixLog(@"login.live.com authorize scope unchanged; legacy scope not found");
            }
        }
    }

    if ([host isEqualToString:@"services.xboxlive.com"]) {
        NSString* targetHost = [[[url absoluteString] lowercaseString] rangeOfString:@"achievements"].location == NSNotFound ? @"profile.xboxlive.com" : @"achievements.xboxlive.com";
        NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        components.host = targetHost;
        [mutable setURL:[components URL]];
        [mutable setValue:targetHost forHTTPHeaderField:@"Host"];
        url = [mutable URL];
        host = targetHost;
        SASSFixLog(@"rewrote services.xboxlive.com to %@", targetHost);
    }

    BOOL xboxServiceHost = [host isEqualToString:@"profile.xboxlive.com"] || [host isEqualToString:@"achievements.xboxlive.com"] || [host isEqualToString:@"titlestorage.xboxlive.com"];
    if (xboxServiceHost) {
        if (SASSFixLastXBL3Auth) {
            [mutable setValue:SASSFixLastXBL3Auth forHTTPHeaderField:@"Authorization"];
            NSString* contract = [mutable valueForHTTPHeaderField:@"x-xbl-contract-version"];
            if (!contract) {
                [mutable setValue:@"2" forHTTPHeaderField:@"x-xbl-contract-version"];
            }
            SASSFixLog(@"attached XBL3 auth to %@%@", host, contract ? @"" : @"; set x-xbl-contract-version=2");
        } else {
            SASSFixLog(@"no cached XBL3 auth for %@", host);
        }
    }
    if ([host isEqualToString:@"achievements.xboxlive.com"]) {
        NSURLComponents* components = [NSURLComponents componentsWithURL:[mutable URL] resolvingAgainstBaseURL:NO];
        NSMutableArray* items = [[components.queryItems mutableCopy] autorelease];
        for (NSUInteger i = 0; i < [items count]; i++) {
            NSURLQueryItem* item = [items objectAtIndex:i];
            if ([item.name isEqualToString:@"titleid"]) {
                [items replaceObjectAtIndex:i withObject:[NSURLQueryItem queryItemWithName:@"titleId" value:item.value]];
                components.queryItems = items;
                [mutable setURL:[components URL]];
                SASSFixLog(@"rewrote achievements titleid query parameter");
                break;
            }
        }
    }
    return mutable;
}

@interface SASSFixURLProbe : NSURLProtocol <NSURLConnectionDataDelegate>
@property(nonatomic, retain) NSURLConnection* connection;
@end

@implementation SASSFixURLProbe

@synthesize connection = _connection;

+ (BOOL)canInitWithRequest:(NSURLRequest*)request {
    NSURL* url = [request URL];
    NSString* host = [[url host] lowercaseString];
    BOOL handled = [NSURLProtocol propertyForKey:@"SASSFixHandledRequest" inRequest:request] != nil;
    BOOL target = [host isEqualToString:@"login.live.com"] ||
        [host isEqualToString:@"services.xboxlive.com"] ||
        [host isEqualToString:@"activeauth.xboxlive.com"] ||
        [host isEqualToString:@"profile.xboxlive.com"] ||
        [host isEqualToString:@"achievements.xboxlive.com"] ||
        [host isEqualToString:@"titlestorage.xboxlive.com"] ||
        [host isEqualToString:@"stats.xboxlive.com"];
    if ([host containsString:@"xboxlive.com"] || [host isEqualToString:@"login.live.com"] || [host isEqualToString:@"login.live-int.com"]) {
        SASSFixLog(@"NSURLProtocol %@ %@", handled ? @"skipping handled" : (target ? @"intercepting" : @"observed"), SASSFixRequestLabel(request));
    }
    return !handled && target;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request {
    return request;
}

- (void)startLoading {
    NSURLRequest* prepared = SASSFixPreparedRequest([self request]);
    NSURL* url = [prepared URL];
    NSString* host = [[url host] lowercaseString];
    NSString* path = [url path] ?: @"";
    NSString* method = [prepared HTTPMethod] ?: @"GET";

    if ([host isEqualToString:@"stats.xboxlive.com"]) {
        NSURLResponse* response = nil;
        BOOL isGET = [method isEqualToString:@"GET"];
        NSData* body = isGET ? [@"{\"leaderboards\":[]}" dataUsingEncoding:NSUTF8StringEncoding] : nil;
        NSData* data = SASSFixHTTP(isGET ? 200 : 204, url, body, isGET ? @"application/json" : nil, &response);
        SASSFixLog(@"short-circuited %@ with HTTP %lu", SASSFixRequestLabel(prepared), (unsigned long)(isGET ? 200 : 204));
        SASSFixFinish(self, response, data);
        return;
    }

    if ([host isEqualToString:@"activeauth.xboxlive.com"] && [path isEqualToString:@"/XSts/xsts.svc/IWSTrust13"]) {
        NSURLResponse* response = nil;
        SASSFixLog(@"handling activeauth SOAP request %@", SASSFixRequestLabel(prepared));
        NSData* data = SASSFixActiveAuthResponse(prepared, &response);
        SASSFixFinish(self, response, data);
        return;
    }

    NSMutableURLRequest* forwarded = [[prepared mutableCopy] autorelease];
    [NSURLProtocol setProperty:@YES forKey:@"SASSFixHandledRequest" inRequest:forwarded];
    SASSFixLog(@"forwarding %@", SASSFixRequestLabel(forwarded));
    if (([host isEqualToString:@"profile.xboxlive.com"] || [host isEqualToString:@"achievements.xboxlive.com"]) && [[forwarded HTTPBody] length]) {
        NSString* body = [[[NSString alloc] initWithData:[forwarded HTTPBody] encoding:NSUTF8StringEncoding] autorelease];
        SASSFixLog(@"request body for %@: %@", SASSFixRequestLabel(forwarded), body ?: [NSString stringWithFormat:@"<%lu non-UTF8 bytes>", (unsigned long)[[forwarded HTTPBody] length]]);
    }
    self.connection = [[[NSURLConnection alloc] initWithRequest:forwarded delegate:self startImmediately:YES] autorelease];
}

- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse*)response statusCode] : 0;
    SASSFixLog(@"forwarded response status=%ld for %@", (long)status, SASSFixRequestLabel([connection currentRequest]));
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    SASSFixLog(@"forwarded request failed for %@: %@", SASSFixRequestLabel([connection currentRequest]), error);
    [[self client] URLProtocol:self didFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    SASSFixLog(@"forwarded request finished for %@", SASSFixRequestLabel([connection currentRequest]));
    [[self client] URLProtocolDidFinishLoading:self];
}

- (NSURLRequest*)connection:(NSURLConnection*)connection willSendRequest:(NSURLRequest*)request redirectResponse:(NSURLResponse*)response {
    NSMutableURLRequest* marked = [[request mutableCopy] autorelease];
    [NSURLProtocol setProperty:@YES forKey:@"SASSFixHandledRequest" inRequest:marked];
    if (response) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse*)response statusCode] : 0;
        SASSFixLog(@"forwarded request redirected status=%ld to %@", (long)status, SASSFixRequestLabel(marked));
        [[self client] URLProtocol:self wasRedirectedToRequest:marked redirectResponse:response];
    }
    return marked;
}

- (void)dealloc {
    [_connection release];
    [super dealloc];
}

@end

static BOOL SASSFixReplaceCloudStorageMethod(Class cls, SEL sel, IMP imp) {
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        SASSFixLog(@"Spartan Strike CloudKit hook missing %@", NSStringFromSelector(sel));
        return NO;
    }
    method_setImplementation(method, imp);
    return YES;
}

static void SASSFixCloudStorageNoOp(id self, SEL _cmd) {
}

static void SASSFixCloudStorageDownload(id self, SEL _cmd, id dataPath, void (^completion)(BOOL, NSData*)) {
    SASSFixLog(@"blocked Spartan Strike CloudKit download %@", dataPath ?: @"(no-path)");
    if (completion) {
        completion(NO, nil);
    }
}

static void SASSFixCloudStorageUpload(id self, SEL _cmd, NSData* data, NSString* filePath, void (^completion)(BOOL)) {
    SASSFixLog(@"blocked Spartan Strike CloudKit upload %@", filePath ?: @"(no-path)");
    if (completion) {
        completion(NO);
    }
}

__attribute__((constructor))
static void SASSFixInit(void) {
    @autoreleasepool {
        NSBundle* bundle = [NSBundle mainBundle];
        NSDictionary* info = [bundle infoDictionary];
        NSString* bundleID = [bundle bundleIdentifier] ?: @"unknown";
        SASSFixLog(@"hook dylib loaded");
        SASSFixLog(@"app %@ version %@ build %@ on %@", bundleID, [info objectForKey:@"CFBundleShortVersionString"] ?: @"unknown", [info objectForKey:@"CFBundleVersion"] ?: @"unknown", [[NSProcessInfo processInfo] operatingSystemVersionString]);
        [NSURLProtocol registerClass:[SASSFixURLProbe class]];
        SASSFixLog(@"registered NSURLProtocol probe");
        if ([bundleID rangeOfString:@"spartanstrike" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            Class cls = NSClassFromString(@"CloudStorage");
            if (cls) {
                BOOL ok = SASSFixReplaceCloudStorageMethod(cls, @selector(checkAccountAvailability), (IMP)SASSFixCloudStorageNoOp);
                ok = SASSFixReplaceCloudStorageMethod(cls, @selector(downloadData:onDownloadCompleted:), (IMP)SASSFixCloudStorageDownload) && ok;
                ok = SASSFixReplaceCloudStorageMethod(cls, @selector(uploadData:filePath:onUploadCompleted:), (IMP)SASSFixCloudStorageUpload) && ok;
                SASSFixLog(@"Spartan Strike CloudKit hook %@; cloud saves disabled", ok ? @"installed" : @"partially installed");
            } else {
                SASSFixLog(@"Spartan Strike CloudKit hook skipped; CloudStorage class not found");
            }
        }
    }
}
