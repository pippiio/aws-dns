function handler(event) {
  var statusCode = 301;
  var description = 'Moved Permanently';
  var headers = {}
  var uri = (typeof event.request.uri !== 'undefined' && event.request.uri !== null) ? event.request.uri : "";
  var query = "";

  if (event.request.querystring) {
    var queryString = event.request.querystring;
    var queryStringArray = [];
    for (var key in queryString) {
        queryStringArray.push(`${key}=${queryString[key].value}`);
    }
    query = '?' + queryStringArray.join('&');
  }

  switch (event.request.headers.host.value) {
%{ for domain, location in redirects ~}
    case '${domain}':
      headers = {'location': { value: '${location}'.replace('<uri>', uri).replace('<query>', query) }}
      break;
%{ endfor ~}

    default:
      var statusCode = 403;
      var description = 'Forbidden';
  }

  return {
    statusCode: statusCode,
    statusDescription: description,
    headers: headers
  };
}