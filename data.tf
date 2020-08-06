data "template_cloudinit_config" "config" {
  gzip          = false
  base64_encode = false  #first part of local config file
  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #!/bin/bash
    apt update
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    apt install -y nodejs
    npm install pm2@4.4.0 -g
    git clone --depth 1 https://github.com/WSMathias/express-sequelize-mysql.git -b v0.0.1
    cd express-sequelize-mysql
    npm i
    npm run migrate
    PORT=80 pm2 start ./bin/www
    EOF
  }
}