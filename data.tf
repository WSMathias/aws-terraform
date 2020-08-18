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


data "template_cloudinit_config" "github_action" {
  gzip          = false
  base64_encode = false  #first part of local config file
  part {
    content_type = "text/x-shellscript"
    content      = templatefile("./github-runner-init.tpl", { 
      ACTION_TOKEN = var.github_action_token
      })
  }
  part {
    content_type = "text/x-shellscript"
    content = <<-EOF
    curl -O -L https://github.com/michenriksen/gitrob/releases/download/v2.0.0-beta/gitrob_linux_amd64_2.0.0-beta.zip
    unzip gitrob_linux_amd64_2.0.0-beta.zip
    cp gitrob /bin/
    EOF
  }

  part {
    content_type = "text/x-shellscript"
    content = <<-EOF
    curl -O -L https://github.com/zricethezav/gitleaks/releases/download/v6.0.0/gitleaks-linux-amd64
    chmod a+x  gitleaks-linux-amd64
    cp gitleaks-linux-amd64 /bin/gitleaks
    EOF

  }
}
