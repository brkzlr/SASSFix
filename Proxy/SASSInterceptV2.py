from mitmproxy import http

import datetime as dt
import json
import re
import urllib.request
import uuid
from urllib.parse import parse_qsl, unquote, urlencode

LEGACY_XBOX_SCOPE = "service::kdc.xboxlive.com::MBI_SSL" # Used for the old XBL2.0 token flow.
MODERN_XBOX_SCOPE = "XboxLive.signin XboxLive.offline_access" # Used for the newer XBL3.0 token flow.

# Collection of dictionaries and vars that store cached tokens for re-use during SA/SS gameplay.
# Using these cuts down the request time significantly, for example achievements retrieval falls down from 2.6 seconds to 160ms
# by re-using the tokens (which expire after a long time anyway) instead of doing a re-routed activeauth call each time.
last_msa_access_token = "" # Last used MSA token during an activeauth call (which happens at game boot/login).
last_xbl3_auth = "" # Cached XBL3.0 auth header string. Realistically this is the only one that will be re-used during a game session.
user_tokens = {} # Dictionary that maps MSA access tokens to user tokens to avoid repeated user/authenticate calls.
xsts_tokens = {} # Ditto but maps (user token, relying party) to XSTS tokens.

def post_json(url: str, payload: dict) -> dict:
    request = urllib.request.Request(
        url,
        json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "x-xbl-contract-version": "1",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def escape_xml(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )


# Grab cached user token if it exists for the specified msa token
# otherwise do a request to get a new user auth token and cache it.
def get_user_token(msa_access_token: str) -> str:
    if msa_access_token in user_tokens:
        return user_tokens[msa_access_token]

    # Try different msa token formats in order until one works.
    # "d=" variant is supposedly the correct one so the call should work from the first try
    # but it doesn't hurt to have fallbacks.
    for ticket in (f"d={msa_access_token}", msa_access_token, f"t={msa_access_token}"):
        try:
            result = post_json(
            "https://user.auth.xboxlive.com/user/authenticate",
                {
                    "RelyingParty": "http://auth.xboxlive.com",
                    "TokenType": "JWT",
                    "Properties": {
                        "AuthMethod": "RPS",
                        "SiteName": "user.auth.xboxlive.com",
                        "RpsTicket": ticket,
                    },
                },
            )
            user_tokens[msa_access_token] = result["Token"]
            return result["Token"]
        except Exception:
            continue

    raise RuntimeError("user/authenticate failed")


# Grab cached XSTS token if it exists for the specified user token + relying party
# otherwise do a request to get a new XSTS token and cache it.
def get_xsts(user_token: str, relying_party: str) -> dict:
    key = (user_token, relying_party)
    if key not in xsts_tokens:
        xsts_tokens[key] = post_json(
        "https://xsts.auth.xboxlive.com/xsts/authorize",
            {
                "RelyingParty": relying_party,
                "TokenType": "JWT",
                "Properties": {
                    "SandboxId": "RETAIL",
                    "UserTokens": [user_token],
                },
            },
        )
    return xsts_tokens[key]


# Generates XBL3.0 x={uhs};{token} header from XSTS response
def xbl3_header(xsts: dict) -> str:
    xui = (xsts.get("DisplayClaims", {}).get("xui") or [{}])[0]
    return f"XBL3.0 x={xui.get('uhs', '')};{xsts['Token']}"


def request(flow: http.HTTPFlow) -> None:
    global last_msa_access_token, last_xbl3_auth

    path = flow.request.path.split("?", 1)[0]

    # Modify live login requests to ask for modern XboxLive scopes instead of the legacy XBL2.0 scope.
    if flow.request.host == "login.live.com":
        if path == "/oauth20_token.srf" and flow.request.method == "POST":
            params = parse_qsl(flow.request.get_text(strict=False), keep_blank_values=True)
            rewritten = [
                (key, MODERN_XBOX_SCOPE if key == "scope" and value == LEGACY_XBOX_SCOPE else value)
                for key, value in params
            ]
            if rewritten != params:
                flow.request.text = urlencode(rewritten)
        elif path == "/oauth20_authorize.srf" and flow.request.method == "GET":
            if flow.request.query.get("scope", "") == LEGACY_XBOX_SCOPE:
                flow.request.query["scope"] = MODERN_XBOX_SCOPE
        return

    # V1 proxy fix included, SS and unpatched SA use service for both profile and achievements calls
    # so we have to modify these to their respective correct URLs.
    if flow.request.host == "services.xboxlive.com":
        target_host = "achievements.xboxlive.com" if "achievements" in flow.request.url else "profile.xboxlive.com"
        flow.request.host = target_host
        flow.request.headers["Host"] = target_host

    # Achievements expects "titleId" with uppercase I instead of all lowercase.
    # Even though it worked perfectly fine so far, doesn't hurt to modify it while we're here already.
    if flow.request.host == "achievements.xboxlive.com" and "titleid" in flow.request.query:
        flow.request.query["titleId"] = flow.request.query.pop("titleid")

    # Game constantly calls Stats which keeps returning denied access or closed off endpoints
    # so MS is possibly blocking stats calls for this specific titleId.
    # We'll silence the game by returning a dummy response on GET or 204 on others.
    if flow.request.host == "stats.xboxlive.com":
        if flow.request.method == "GET":
            flow.response = http.Response.make(
                200,
                b'{"leaderboards":[]}',
                {"Content-Type": "application/json", "Cache-Control": "no-store"},
            )
        else:
            flow.response = http.Response.make(204, b"", {"Cache-Control": "no-store"})
        return

    # Patch the game's request headers to use the newer XBL3.0 token
    if flow.request.host in {"profile.xboxlive.com", "achievements.xboxlive.com", "titlestorage.xboxlive.com"}:
        auth = last_xbl3_auth
        if auth:
            flow.request.headers["Authorization"] = auth
            flow.request.headers["x-xbl-contract-version"] = flow.request.headers.get("x-xbl-contract-version", "2")

    if flow.request.host != "activeauth.xboxlive.com" or path != "/XSts/xsts.svc/IWSTrust13":
        return

    # We reach this section if the game tries to obtain an XSTS token during login.
    # Let's grab the MSA access token from game's request.
    auth = flow.request.headers.get("Authorization", "")
    match = re.search(r"\bt=([^, ]+)", auth)
    if not match:
        flow.response = http.Response.make(401, b"")
        return
    msa_access_token = unquote(match.group(1))

    # Grab existing "xboxlive.com" relying party string if it already exists in this request.
    request_xml = flow.request.get_text(strict=False)
    relying_party = "http://xboxlive.com"
    for address in re.findall(
        r"<(?:[A-Za-z0-9_.-]+:)?Address[^>]*>(.*?)</(?:[A-Za-z0-9_.-]+:)?Address>",
        request_xml,
    ):
        if "xboxlive.com" in address:
            relying_party = address
            break

    # Grab user token from msa, then grab XSTS from user, using the newer XBL3.0 flow.
    try:
        xsts = get_xsts(get_user_token(msa_access_token), relying_party)
        last_msa_access_token = msa_access_token
        last_xbl3_auth = xbl3_header(xsts)
    except Exception:
        flow.response = http.Response.make(502, b"")
        return

    def xml_text(local_name: str) -> str:
        text_match = re.search(
            rf"<(?:[A-Za-z0-9_.-]+:)?{re.escape(local_name)}(?:\s[^>]*)?>(.*?)</(?:[A-Za-z0-9_.-]+:)?{re.escape(local_name)}>",
            request_xml,
            re.DOTALL,
        )
        return text_match.group(1).strip() if text_match else ""

    # Generate the needed SOAP response parameters
    now = dt.datetime.now(dt.timezone.utc)
    issue = xsts.get("IssueInstant", now.replace(microsecond=0).isoformat().replace("+00:00", "Z"))
    expires = xsts.get(
        "NotAfter",
        (now + dt.timedelta(hours=12)).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    )
    message_id = xml_text("MessageID") or f"urn:uuid:{uuid.uuid4()}"
    token_type = xml_text("TokenType") or "http://docs.oasis-open.org/wss/oasis-wss-saml-token-profile-1.1#SAMLV2.0"
    token = escape_xml(xsts["Token"])

    # Return the SOAP response SA/SS is expecting
    flow.response = http.Response.make(
        200,
        f"""<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://docs.oasis-open.org/ws-sx/ws-trust/200512/RSTRC/IssueFinal</a:Action>
    <a:RelatesTo>{escape_xml(message_id)}</a:RelatesTo>
  </s:Header>
  <s:Body>
    <trust:RequestSecurityTokenResponseCollection xmlns:trust="http://docs.oasis-open.org/ws-sx/ws-trust/200512">
      <trust:RequestSecurityTokenResponse>
        <trust:TokenType>{escape_xml(token_type)}</trust:TokenType>
        <trust:Lifetime>
          <u:Created>{escape_xml(issue)}</u:Created>
          <u:Expires>{escape_xml(expires)}</u:Expires>
        </trust:Lifetime>
        <trust:RequestedSecurityToken>
          <wsse:BinarySecurityToken
            xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
            EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
            ValueType="urn:xboxlive:jwt">{token}</wsse:BinarySecurityToken>
        </trust:RequestedSecurityToken>
      </trust:RequestSecurityTokenResponse>
    </trust:RequestSecurityTokenResponseCollection>
  </s:Body>
</s:Envelope>""".encode("utf-8"),
        {"Content-Type": "application/soap+xml; charset=utf-8", "Cache-Control": "no-store"},
    )
