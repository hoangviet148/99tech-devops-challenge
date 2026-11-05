function handler(event) {
  var request = event.request;
  var path;
  try {
    path = decodeURIComponent(request.uri);
  } catch (e) {
    return { statusCode: 400, statusDescription: "Bad Request" };
  }
  if (/^\/releases\/.+\/index\.html$/.test(path)) {
    return { statusCode: 404, statusDescription: "Not Found" };
  }
  var name = request.uri.substring(request.uri.lastIndexOf("/") + 1);
  if (name.lastIndexOf(".") <= 0) {
    request.uri = "/index.html";
  }
  return request;
}
