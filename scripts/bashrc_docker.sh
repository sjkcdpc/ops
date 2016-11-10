# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias psp="ps -e -o'pcpu,pmem,rsz,pid,comm,args'|sort -k1,2nr|head -n 50"
alias hc='history -c;clear'

goto () {
	containers="$(docker ps|awk '{print $NF}'|grep -v -e '^NAMES$')"

	if [ -z $1 ];then
		echo "CONTAINER ID|NAME missing,Usage:"
		for container_name in $containers;do
			echo -e "\t\tgoto ${container_name}"
		done
		return 1
	else
		my_container="$1"
		container_name=$(echo $containers|grep -o -P -e "[^ ]*${my_container}[^ ]*"|head -n 1)
		if [ -z "${container_name}" ];then
			echo "${my_container} not running or not exist."
		else
			echo "goto ${container_name}"
			docker exec -i -t ${container_name} '/bin/bash'
		fi
	fi

}

docker_stop_all_container() {
	for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|tr '\n' ' '`; do docker stop $ctn;done
}

docker_start_all_container() {
	for ctn in `docker ps -a|awk '{print $NF}'|grep -v -e '^NAMES'|tr '\n' ' '`; do docker start $ctn;done
}

docker_run_a_cmd_on_all_container() {
	if [ -z "$1" ] ;then echo usage:docker_run_a_cmd_on_all_container "cmd";return 1;fi
	for ctn in `docker ps -a|awk '{print $NF}'|grep -v -e '^NAMES'|grep icc_app|tr '\n' ' '`; do
		echo "${ctn} result: "
		docker exec -i ${ctn} bash -c "$1" 
		echo
	done
}

docker_stats() {
	docker stats `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|tr '\n' ' '`
}

chownmod_tmpdir() {
	chown -R nobody.nobody /tmp/icc_appserver_c*
	find /tmp/icc_appserver_c* -type d -exec chmod -R 755 {} \;
	find /tmp/icc_appserver_c* -type f -exec chmod -R 644 {} \;
}

ngx_reload() {
	chownmod_tmpdir &>/dev/null &
	for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|grep -e 'icc_appserver'|tr '\n' ' '`; do
		echo "${ctn} reload nginx : "
		docker exec -i ${ctn} /usr/local/tengine/sbin/nginx -s reload
		echo $?
	done
}

ngx_restart() {
	for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|grep -e 'icc_appserver'|tr '\n' ' '`; do
		echo "${ctn} restart nginx : "
		docker exec -i ${ctn} bash -c '/usr/local/tengine/sbin/nginx -s stop &>/dev/null; /usr/local/tengine/sbin/nginx -s stop &>/dev/null; /usr/local/tengine/sbin/nginx'
		echo $?
	done
}

php_restart() {
	chownmod_tmpdir &>/dev/null &
	for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|grep -e 'icc_appserver'|tr '\n' ' '`; do
		echo "${ctn} stop nginx : "
		docker exec -i ${ctn} bash -c '/usr/local/tengine/sbin/nginx -s stop &>/dev/null; /usr/local/tengine/sbin/nginx -s stop &>/dev/null'
		echo "${ctn} restart php-fpm : "
		docker exec -i ${ctn} sed -i 's|\(^[ |\t]*_use_systemctl=1$\)|#\1|' /etc/init.d/functions
		docker exec -i ${ctn} /etc/init.d/php-fpm restart
		echo "${ctn} start nginx : "
		docker exec -i ${ctn} bash -c '/usr/local/tengine/sbin/nginx'
		echo $?
	done
}

pyweixin_restart() {
	#for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|grep -e 'py_weixin_service'|tr '\n' ' '`; do
	#	#echo "${ctn} restart python_weixin_service: "
	#	docker exec -i ${ctn} bash -c "/usr/bin/supervisorctl -c /etc/supervisor.conf restart 'py_weixin_service:py_weixin_service0'"
	#	#echo $?
	#done
	docker restart py_weixin_service_1
}

pyweixin_status() {
	#for ctn in `docker ps|awk '{print $NF}'|grep -v -e '^NAMES'|grep -e 'py_weixin_service'|tr '\n' ' '`; do
	#	#echo "${ctn} check python_weixin_service: "
	#	docker exec -i ${ctn} bash -c "/usr/bin/supervisorctl -c /etc/supervisor.conf status"
	#	#echo $?
	#done
	docker ps|grep -e 'STATUS' -e 'py_weixin_service'
}

swoolechat_restart() {
	local port="$1"
	local project="$2"
	local sw_param=" -a /home/webs/$project/swoolchat"
	local ctn=$(docker ps -a|grep "${port}->"|awk '{print $NF}')
	#if 
	#if [ "$port" = '9503' ];then
	#	local ctn='app05_icc_appserver_c09'
	#	local project="160523fg0262"
	#elif [ "$port" = '9504' ];then
	#	local ctn='app05_icc_appserver_c08'
	#	#local project="zhibodemo"
	#	local project="160612fg0304demo"
	#elif [ "$port" = '9505' ];then
	#	local ctn='app05_icc_appserver_c07'
	#	#local project="zhibo"
	#	local project="160612fg0304"
	#else
	#	:
	#fi
	if [ -z "$1" -o -z "$2" -o -z "$ctn" ];then
		echo "parameter missing,nothing done,usage: swoolechat_restart port project"
		return 1
	fi
	
	docker restart ${ctn}
	docker exec ${ctn} bash -c ". /etc/profile;php /home/webs/${project}/swoolchat/webim_server.php $sw_param >> /tmp/swoolechat.log 2>&1 &" &
	docker exec ${ctn} bash -c "ps -ef|grep '/home/webs/${project}/swoolchat/webim_server.php'|grep -v -e grep"
	docker exec -i ${ctn} sed -i 's|\(^[ |\t]*_use_systemctl=1$\)|#\1|' /etc/init.d/functions
	docker exec -i ${ctn} bash -c '/etc/init.d/php-fpm restart' #&>/dev/null
	docker exec -i ${ctn} bash -c '/etc/init.d/php-fpm status' #&>/dev/null
	docker exec -i ${ctn} bash -c '/usr/local/tengine/sbin/nginx' # &>/dev/null
	docker exec -i ${ctn} bash -c '/usr/local/tengine/sbin/nginx -s reload' # &>/dev/null
}

swoolechat_status() {
	local port="$1"
	local ctn=$(docker ps -a|grep "${port}->" 2>/dev/null | awk '{print $NF}')
	if [ -z "$1" -o -z "$ctn" ];then
		echo "parameter missing,nothing done,usage: swoolechat_restart port project"
		return 1
	fi
	#docker exec -i ${ctn} bash -c "ps -ef|grep -e 'swoolchat/webim_server.php'|grep -e manager|grep -v -e grep" |tr -d '\n'
	local instance_stime_project=$(docker exec -i ${ctn} bash -c "ps -ef|grep -e 'swoolchat/webim_server.php'|grep -e manager|grep -v -e grep" \
	| awk '{gsub('/.home.webs.\|.swoo.*$/',"",$9);print $5,$9}')
	local connections=$(docker exec ${ctn} ss -nt|grep 9503|wc -l)
	local process_number=$(docker exec ${ctn} ps -ef|grep -e 'swoolchat/webim_server.php'|wc -l)
	echo -n $instance_stime_project process_number:$process_number connections:$connections
	
}

containers_outconnects() {
	docker_run_a_cmd_on_all_container \
	"ss -nt|grep -v -e '^State' -e 'LISTEN' -e '10.0.0' -e '172.18.1' -e '127.0.0.1' | wc -l" \
	| grep -v -e '^$' -e 'result:' | awk '{sum += $1}END{print sum}'
}

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
