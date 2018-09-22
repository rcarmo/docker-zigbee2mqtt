export ARCH?=$(shell arch)
ifneq (,$(findstring armv6,$(ARCH)))
export BASE=arm32v6/ubuntu:18.04
export ARCH=arm32v6
else ifneq (,$(findstring armv7,$(ARCH)))
export BASE=arm32v7/ubuntu:18.04
export ARCH=arm32v7
else
export BASE=ubuntu:18.04
export ARCH=amd64
endif
export IMAGE_NAME=rcarmo/zigbee2mqtt
export HOSTNAME?=zigbee2mqtt
export DATA_FOLDER=$(HOME)/.zigbee2mqtt
export VCS_REF=`git rev-parse --short HEAD`
export VCS_URL=https://github.com/rcarmo/docker-zigbee2mqtt
export BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
export TAG_DATE=`date -u +"%Y%m%d"`

build: Dockerfile
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BASE=$(BASE) \
		-t $(IMAGE_NAME):$(ARCH) .

tag:
	docker tag $(IMAGE_NAME):$(ARCH) $(IMAGE_NAME):$(ARCH)-$(TAG_DATE)

push:
	docker push $(IMAGE_NAME)

network:
	-docker network create -d macvlan \
	--subnet=192.168.1.0/24 \
        --gateway=192.168.1.254 \
	--ip-range=192.168.1.128/25 \
	-o parent=eth0 \
	lan

shell:
	docker run --net=lan -h $(HOSTNAME) -it $(IMAGE_NAME):$(ARCH) /bin/sh

test: 
	docker run -v $(DATA_FOLDER):/home/user/.homebridge \
		--net=host -h $(HOSTNAME) $(IMAGE_NAME):$(ARCH)

logs:
	docker logs -f $(HOSTNAME)

truncate:
	sudo truncate -s 0 $$(docker inspect --format='{{.LogPath}}' $(HOSTNAME))

daemon: 
	-mkdir -p $(DATA_FOLDER)
	docker run -v $(DATA_FOLDER):/home/user/.homebridge \
		-v /var/run/dbus:/var/run/dbus \
		--net=host --name $(HOSTNAME) -d --restart unless-stopped $(IMAGE_NAME):$(ARCH)

clean:
	-docker rm -v $$(docker ps -a -q -f status=exited)
	-docker rmi $$(docker images -q -f dangling=true)
	-docker rmi $$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '$(IMAGE_NAME)')
