function handler(event) {
  var statusCode = 301;
  var description = 'Moved Permanently';
  var headers = {}

  switch (event.request.headers.host.value) {
%{ for domain, location in redirects ~}
    case '${domain}':
      var headers = {'location': { value: '${location}' }}
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