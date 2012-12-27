root@createtest.awsnginx ~ # cat runtest.sh 
#!/bin/bash -x


TESTDIR=/root/sysbench/
mkdir -p ${TESTDIR}/variables

test -f /usr/bin/mysql || yum install -y Percona-Server-client-55 >/dev/null 2>&1
test -f /root/sysbenchtest/sysbench || exit
while true
do 
	test -f /root/hosttotest.env && break
	sleep 5
done

source /root/hosttotest.env
echo "show global variables" | /usr/bin/mysql --host=${HOSTTOTEST} --user=${TESTUSER} --password=${TESTPASSWORD} ${TESTDB} > ${TESTDIR}/variables/${HOSTTOTEST}-iops${IOPS}-storage${STORAGE}-class${CLASS}-multiaz${MULTIAZ}-master${MASTER}-dbversion${DBVERSION}.`date +%s`

echo "drop view if exists ps_state1" | /usr/bin/mysql --host=${HOSTTOTEST} --user=${TESTUSER} --password=${TESTPASSWORD} sbtest
echo "create view  ps_state1 as  SELECT  REPLACE(SUBSTRING_INDEX(object_name, '/', -1),'.','_')  file,  timer_wait/1000000 latency_usec, operation, number_of_bytes bytes FROM performance_schema.events_waits_history_long JOIN performance_schema.threads USING (thread_id) LEFT JOIN information_schema.processlist ON processlist_id = id WHERE object_name IS NOT NULL ORDER BY timer_start" | /usr/bin/mysql --host=${HOSTTOTEST} --user=${TESTUSER} --password=${TESTPASSWORD} sbtest
 

#warmup 

/root/sysbenchtest/sysbench  --test=oltp --mysql-table-engine=innodb  --oltp-table-size=1000000000 --mysql-user=${TESTUSER} --mysql-password=${TESTPASSWORD} --mysql-host=${HOSTTOTEST}  --num-threads=3 --max-requests=0 --max-time=300  --oltp-order-ranges=1 --oltp-distinct-ranges=5 --oltp-index-updates=1 --oltp-user-delay-max=10  --oltp-test-mode=complex  run > /dev/null 2>&1




for i in 2 4 8 12 16 20 24 28 32 64 128
do 

	sleep 60
	echo "${CLASS}.iops${IOPS}.storage${STORAGE}.multiaz${MULTIAZ}.master${MASTER}.$DBVERSION.start ${i} `date +%s`" | nc graphite 2003



	/root/sysbenchtest/sysbench  --test=oltp --mysql-table-engine=innodb  --oltp-table-size=1000000000 --mysql-user=${TESTUSER} --mysql-password=${TESTPASSWORD} --mysql-host=${HOSTTOTEST}  --num-threads=${i} --max-requests=0 --max-time=1800 --oltp-order-ranges=1 --oltp-distinct-ranges=5 --oltp-index-updates=1 --oltp-user-delay-max=10  --oltp-test-mode=complex  run >  /tmp/$$.out

	mkdir -p ~sysbench/`hostname -f`
	cp /tmp/$$.out  ~sysbench/`hostname -f`/${IOPS}-${STORAGE}-${CLASS}-${MULTIAZ}-${MASTER}-${i}.sysbench.out


	echo "${CLASS}.iops${IOPS}.storage${STORAGE}.multiaz${MULTIAZ}.master${MASTER}.$DBVERSION.end ${i} `date +%s`" | nc graphite 2003
	rm -f /tmp/$$.out

done
