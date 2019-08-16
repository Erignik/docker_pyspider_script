#!/bin/bash
mysql_password=password
mysql_port=3306
redis_port=6379
scheduler_port=23333
mysql_home=path/to/mysql
mysql_home_cnf=$mysql_home/conf/my.cnf
mysql_home_logs=$mysql_home/logs
mysql_home_data=$mysql_home/data
pyspider_collect_data=/path/to/collect_data

docker network list | grep "pyspider"
if [ $? -ne 0 ] ;then
    echo "do not has network, create network"
    docker network create --driver bridge pyspider
else
    echo "has network"
fi

docker ps | grep redis
if [ $? -ne 0 ] ;then
    eval "docker run --network=pyspider "\
               "--restart=always "\
               "--name redis -d -p "$redis_port":6379 redis"
    echo "do not start redis, create redis"
else
    echo "has redis"
fi

docker ps | grep pymysql
if [ $? -ne 0 ] ;then
    echo "do not start pymysql, create pymysql"
    eval "docker run --network=pyspider "\
               "--restart=always "\
               "-p "$mysql_port":3306 "\
               "--name pymysql "\
               "-v "$mysql_home_cnf":/etc/mysql/my.cnf "\
               "-v "$mysql_home_logs":/logs "\
               "-v "$mysql_home_data":/var/lib/mysql "\
               "-e MYSQL_ROOT_PASSWORD="$mysql_password" -d mysql:5.7.27"
else
    echo "has pymysql"
fi

redis_ip=`docker inspect redis | grep '"IPAddress": "172.' | sed 's/.*IPAddress.*"\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/g'`
mysql_ip=`docker inspect pymysql | grep '"IPAddress": "172.' | sed 's/.*IPAddress.*"\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/g'`


docker ps | grep scheduler
if [ $? -ne 0 ] ;then
    echo "do not start scheduler, create scheduler"
    eval docker run --network=pyspider \
               --name scheduler \
               -d -p $scheduler_port:23333 \
               --restart=always \
               binux/pyspider \
               --taskdb "mysql+taskdb://root:"$mysql_password"@"$mysql_ip":"$mysql_port"/taskdb" \
               --resultdb "mysql+projectdb://root:"$mysql_password"@"$mysql_ip":"$mysql_port"/resultdb" \
               --projectdb "mysql+projectdb://root:"$mysql_password"@"$mysql_ip":"$mysql_port"/projectdb" \
               --message-queue "redis://"$redis_ip":"$redis_port"/0" scheduler \
               --inqueue-limit 10000 --delete-time 3600
else
    echo "has scheduler"
fi

docker ps | grep processor
if [ $? -ne 0 ] ;then
    echo "do not start processor, create processor"
    rm -rf pyspider.yml
    cp pyspider_tmp.yml pyspider.yml
    eval sed -i s/mysql_password/$mysql_password/g pyspider.yml
    eval sed -i s/mysql_port/$mysql_port/g pyspider.yml
    eval sed -i s/redis_port/$redis_port/g pyspider.yml
    eval sed -i s/scheduler_port/$scheduler_port/g pyspider.yml
    eval sed -i s/redis_ip/$redis_ip/g pyspider.yml
    eval sed -i s/mysql_ip/$mysql_ip/g pyspider.yml
    eval sed -i s#pyspider_collect_data#$pyspider_collect_data#g pyspider.yml
    docker-compose -f pyspider.yml up -d
else
    echo "has processor"
fi

echo "starting up end."
