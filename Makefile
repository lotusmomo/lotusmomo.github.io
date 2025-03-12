.PHONY: clean build serve local-deploy remote-deploy all prod
.DEFAULT_GOAL := all

clean:
	npx hexo clean

build:
	npx hexo generate

serve:
	while ((1)); do npx hexo clean && npx hexo s -d; done

local-deploy: clean build
	cp -r public/* /opt/homebrew/var/www

remote-deploy: local-deploy
	ssh root@10.10.2.21 "rm -rf /data/wwwroot/lotusmomo.cn/*"
	rsync -avz --delete public/ root@10.10.2.21:/data/wwwroot/lotusmomo.cn

all: local-deploy

prod: remote-deploy