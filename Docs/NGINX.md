# Nginx reverse proxy

Use este bloco no servidor para mapear `/ServidorLog` para o Horse na porta 9100.

```nginx
location /ServidorLog/ {
    proxy_pass http://127.0.0.1:9100/ServidorLog/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Validacao rapida:

`curl https://fiscalfacil.com/ServidorLog/health`
