user www-data;
worker_processes  3;

error_log  /var/log/nginx/error.log;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}


# start the http module where we config http access.
http {
  # pull in mime-types. You can break out your config 
  # into as many include's as you want to make it cleaner
  include /etc/nginx/mime.types;
  
  # set a default type for the rare situation that
  # nothing matches from the mimie-type include
  default_type  application/octet-stream;

  # configure log format
  log_format main '$remote_addr - $remote_user [$time_local] $status '
                  '"$request" $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';

  # main access log
  access_log  /var/log/nginx_access.log  main;

  # main error log
  error_log  /var/log/nginx_error.log debug;

  sendfile on;

  # increase the url length limit
  server_names_hash_bucket_size  128;

  # These are good default values.
  tcp_nopush        on;
  tcp_nodelay       off;
  # output compression saves bandwidth 
  gzip            on;
  gzip_http_version 1.0;
  gzip_comp_level 2;
  gzip_proxied any;
  gzip_types      text/plain text/html text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript;