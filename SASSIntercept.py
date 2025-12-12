from mitmproxy import http

class SASSIntercept:
    def request(self, flow: http.HTTPFlow) -> None:
        if "services" in flow.request.host:
            if "achievements" in flow.request.url:
                flow.request.host = "achievements.xboxlive.com"
            else:
                flow.request.host = "profile.xboxlive.com"

addons = [SASSIntercept()]
