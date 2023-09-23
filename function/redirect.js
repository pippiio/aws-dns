function handler(event) {
  var location;

  switch (event.request.headers.host.value) {
%{ for location, domains in redirects ~}
%{ for domain in domains ~}
    case '${domain}':
%{ endfor ~}
      location = '${location}';
      break;
%{ endfor ~}

    default:
      return {
        statusCode: 403,
        statusDescription: 'Forbidden',
      };
  }

  var uri = (typeof event.request.uri !== 'undefined' && event.request.uri !== null) ? event.request.uri : "";
  if (event.request.querystring) {
    var queryString = event.request.querystring;
    var queryStringArray = [];
    for (var key in queryString) {
      queryStringArray.push(`$${key}=$${queryString[key].value}`);
    }
    var query = queryStringArray.length > 0 ? '?' + queryStringArray.join('&') : '';
  }

  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: {'location': { value: location.replace('<uri>', uri).replace('<query>', query) }}
  };
}
