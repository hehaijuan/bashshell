#!/bin/sh
#  Author        ：hehaijuan
#  Email         : jennyhe@jlq.com
#  notes         : be fit for 310 BSP script
# ********************************************************
# *****************************定义log输出文件的格式*******************************************
#设置日志级别
loglevel=0 #debug:0; info:1; warn:2; error:3
logfile="./logout"/$(date -d "today" +"%Y%m%d_%H%M%S").log #定义的log地址
function log(){
    local msg;local logtype
    logtype=$1
    msg=$2
    datetime=`date +'%F %H:%M:%S'`
    #使用内置变量$LINENO不行，不能显示调用那一行行号
    #logformat="[${logtype}]\t${datetime}\tfuncname:${FUNCNAME[@]} [line:$LINENO]\t${msg}"
    logformat="[${logtype}]\t${datetime}\tfuncname: ${FUNCNAME[@]/log/}\t[line:`caller 0 | awk '{print$1}'`]\t${msg}"
    #funname格式为log error main,如何取中间的error字段，去掉log好办，再去掉main,用echo awk? ${FUNCNAME[0]}不能满足多层函数嵌套
    {  
    case $logtype in 
        debug)
            [[ $loglevel -le 0 ]] && echo -e "\033[30m${logformat}\033[0m" ;;
        info)
            [[ $loglevel -le 1 ]] && echo -e "\033[32m${logformat}\033[0m" ;;
        warn)
            [[ $loglevel -le 2 ]] && echo -e "\033[33m${logformat}\033[0m" ;;
        error)
            [[ $loglevel -le 3 ]] && echo -e "\033[31m${logformat}\033[0m" ;;
    esac
    } | tee -a $logfile
}
# *******************************************定义导出测试报告的**********************************
function report(){
echo "++++++总测试结果++++++++++++++++++++++++++++++++++++++++++++++" 
#展示所有用例的测试结果：
awk 'BEGIN{printf "%-10s\t %s\n","用例名称","测试结果"} /Fail/||/轮测试/||/Pass/{printf "%-10s\t %s\n",$8,$10}' ${logfile}
echo "++++++Fail的测试结果++++++++++++++++++++++++++++++++++++++++++++++" 
#展示Fail用例的测试结果：
#awk -v OFS="   " '{print $2,$3,$8,$9}' ${logfile}
awk 'BEGIN{printf "%-10s\t %s\n","用例名称","测试结果"} /Fail/||/轮测试/{printf "%-10s\t %s\n",$8,$10}' ${logfile}
}
#*******************************************common 公共的方法函数******************
tempfile="./logout/temp.txt"   #定义临时处理的文件的地址
#********fretimes 获取某个频段的运行时间*************
#**    From  :   To
#**                :       762      1525      3051      4066   time(ms)
#**             762:         0         1         1         2  47124644
#**            1525:         2         0         0         0  24472928
#**     *      3051:         0         0         0         0    873912
#**            4066:         2         1         0         0 109172920
#**    Total transition : 9

#参数解释：$1——所在的频率，$2——比较的文件
fretimes(){
	A=$1
	file=$2
	#awk '$1==790 {print var1=$5}' ${file}
	case $1 in
	3051:) z=`awk -v pat="$A" '$2==pat { print $7}' ${file}`
	;;
	*) z=`awk -v pat="$A" '$1==pat { print $6}' ${file}`
	esac
	echo $z
}
#*******fredif——比较获取某个频段的运行时间大于0******
#参数解释：$1——所在的频率
fredif(){
	adb shell cat /sys/class/devfreq/devfreq0/trans_stat >${tempfile}
	fretimes $1 ${tempfile} 
	time1=$z
	#sleep 1
	adb shell cat /sys/class/devfreq/devfreq0/trans_stat >${tempfile}
	fretimes $1 ${tempfile}
	time2=$z
}
#********************************根据输出的测试用例转化为自动化脚本，以下为测试用例函数部分，测试用例编号为函数名称**********************
#**********clock_1————查看clk_summary文件内容中rate列是否有为空的行
clock_1(){
	Tag="clock_1"
	#1、挂载文件
	adb shell mount –t debugfs none /sys/kernel/debug
	#2、获取clk_summary文件的内容
	adb shell cat /sys/kernel/debug/clk/clk_summary 2>&1 |tee ${tempfile}
	#3、获取clk_summary文件的内容中rate列是否为空，
	count=`awk -F: 'BEGIN {a=0} { if (NF<6) a=a+1} END {print a}' ${tempfile}`#导出文件统计列数小于6的行数和， 
	#如果和大于0，则为FAIL，等于0则为PASS
	if [ &count -ne 0 ]
	then
		log info "all clock is not none"
	else
		log error "${Tag} step1 Fail"
	fi
	log info "${Tag} test Pass"
}
#**********************测试函数**********************************************
#test(){
#	adb shell ls /data/1/bsptest
#	adb shell cat /data/1/bsptest/main.sh
#	echo "helloworld"
#	log info "test step Pass"
#	log error "test step Fail"
#	log info "test step Pass"
#}
#test(){
#my_array=(hello world mama oh)
#for per in ${my_array[@]}
#do
#	log info "$per"
#done
#}
#test(){
#my_array=(hello world mama oh)
#for per in ${my_array[@]}
#do
#	log info "$per"
#done
#}
test(){
addr="bsptest"
adb shell ls /data/$addr
}
#********************main**********************************************
log info "begin"
for((i=1;i<=$1;i++));
do
echo "第${i}轮测试" >> $logfile
log info "go 第$i轮测试"
arr_fun=(clock_1)  #需要测试的测试用例
for fun in ${arr_fun[@]}
do
	${fun}
done
log info "done"
#********************导出测试报告******************************************
report="./logout"/"result"_$(date -d "today" +"%Y%m%d_%H%M%S").log  #定义测试报告输出文件
report 2>&1 |tee -a $report
