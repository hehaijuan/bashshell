#!/bin/sh
#  Author        ：hehaijuan
#  Email         : jennyhe@jlq.com
#  notes         : be fit for 310 BSP Logging script
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
#**********devfreq_4———available_frequencies接口可以正常查看支持哪些频率*****
#参数解释：$1——用例名称/用例函数名称 $2——接口名称 $3——支持的频率标准
interfreq(){
	Tag = $1
	#第一步：cat $2接口支持哪些频率
	addr=sys/class/devfreq/devfreq0/$2
	adb shell cat $addr |tee $tempfile
	my_array=$3
	for tempdata in ${my_array[@]}
	do
		echo ${tempdata}
		grep ${tempdata} ${tempfile}
		if [ $? -eq 0 ]
		then
			log info "${Tag} step1 pass"
		else
			log error "${Tag} step1 Fail"
			return 0
		fi
	done
	log info "${Tag} step1 Pass"
	}
#*******setfreq——设置当前调频策略*******************
#参数解释：$1——用例名称/用例函数名称 $2——设置的调频策略，比如：jlq_bwmon/powersave/performance
setfreq(){
	Tag = $1
	#1、设置调频状态为$2
	adb shell "echo $2 > /sys/class/devfreq/devfreq0/governor"
	#2、检查当前状态是否是$2
	adb shell cat /sys/class/devfreq/devfreq0/governor
	for per in `adb shell cat /sys/class/devfreq/devfreq0/governor`
	do
		echo $Tag step2:$per
		if [ $per -eq $2]
		then
			log info "$2 is correct"
		else
			log error "${Tag} step2 Fail"
			return 0
		fi
	done
	#3、检查当前状态频率是否为对应的频率值&freqence
	case $2 in
		jlq_bwmon) freqence=1525 ;;
		powersave) freqence=761;;
		performance) freqence=4066;;
	esac
	echo $freqence

	adb shell cat /sys/class/devfreq/devfreq0/cur_freq
	for per in `adb shell cat /sys/class/devfreq/devfreq0/cur_freq`
	do
		echo $Tag step3:$per
		if [ $per -eq $freqence ]
		then
	   		log info "setfreqence is strategy is ok"
		else
	   		log error "${Tag} step3 Fail"
			return 0
		fi
	done
	#4、检查当前状态trans_stat节点中$freqence频率运行时间是否增加
	fredif "1525:"
	echo demoFun-arg3:$time1;demoFun-arg3:$time2
	if [ $time2 -gt $time1 ]
		then
			log info "running time increases"
		else
			log error "${Tag} step4 Fail"
			return 0
	fi
	log info "${Tag} test Pass"
}
#******common——userfreq————设置userspace为合法值****************************************************
#参数解释：$1——用例名称/用例函数名称 $2——设置的频率值
userfreq(){
	Tag = $1  #$1传入函数名称，即为用例名称
	#1、设置调频状态为userspace
	adb shell "echo userspace > /sys/class/devfreq/devfreq0/governor"
	#2、检查当前状态是否是userspace
	adb shell cat /sys/class/devfreq/devfreq0/governor
	for per in `adb shell cat /sys/class/devfreq/devfreq0/governor`
	do
		echo $Tag step2:$per
		if [ $per -eq userspace ]
		then
			log info "The current state is userspace"
		else
			log error "${Tag} step2 Fail"
			return 0
		fi
	done
	#3、检查devfreq接口下是否多了一个userspace接口用于设置频率
	adb shell cat /sys/class/devfreq/devfreq0/
	#4、设置频率为$2的值
	adb shell"echo $2 > /sys/class/devfreq/devfreq0/userspace/set_freq"
	#5、检查当前设置频率是否为设置的值
	adb shell cat  /sys/class/devfreq/devfreq0/userspace/set_freq
	for per in `adb shell cat  /sys/class/devfreq/devfreq0/userspace/set_freq`
	do
		echo $Tag step5:$per
		if [ $per -eq $2 ]
		then
			log info "Frequency is the set value"
		else
			log error "${Tag} step5 Fail"
			return 0
		fi
	done
	#6、检查当前状态频率是否为对应的频段上工作$freq
	if [ $2 -le 762 ]
	then
		freq=762
		echo $freq
	elif [[ $2 -gt 762 && $2 -le 1525 ]]
	then
		freq=1525
		echo $freq
	elif [[ $2 -gt 1525 && $2 -le 3051 ]]
	then
		freq=3051
		echo $freq
	else
		freq=4066
		echo $freq
	fi
	adb shell cat /sys/class/devfreq/devfreq0/cur_freq
	for per in `adb shell cat /sys/class/devfreq/devfreq0/cur_freq`
	do
		echo $Tag step6:$per
		if [ $per -eq $freq ]
		then
			log info "Frequency is the operating frequency of the corresponding frequency band"
		else
			log error "${Tag} step6 Fail"
			return 0
		fi
	done
	#7、检查当前状态trans_stat接口中相应频率运行时间时是否增加
	fredif "$freq:"
	echo $Tag:$time1;$Tag:$time2
	if [ $time2 -gt $time1 ]
	then
		log info "running time increases"
	else
		log error "${Tag} step7 Fail"
		return 0
	fi
	log info "${Tag} test Pass"
}
#********************************根据输出的测试用例转化为自动化脚本，以下为测试用例函数部分，测试用例编号为函数名称**********************
#**********devfreq_1————检查系统正常启动，无调试log打印***********NOT自动化
#**********devfreq_2————检查sys/class下设备节点正常********成需要提供节点的txt文件更改my_array的值
devfreq_2(){
	Tag="devfreq_2"
	#第一步：cd sys/class
	#第二步：ls
	adb shell ls sys/class |tee $tempfile 
	my_array=(backlight graphics misc regulator bdi net rtc tee devfreq dma gpio ppp pwm)
	for tempdata in ${my_array[@]}
	do
		echo ${tempdata}
		grep ${tempdata} ${tempfile}
		if [ $? -eq 0 ]
		then
			log info "The node is correct"
		else
			log error "${Tag} step2 Fail"
			return 0
		fi
	done
	log info "${Tag} test Pass"
}
#**********devfreq_3————dev_freq下接口正常************
devfreq_3(){
	Tag = devfreq_3
	#第一步：cd sys/class/devfreq/devfreq0
	#第二步：ls
	adb shell ls sys/class/devfreq/devfreq0 |tee $tempfile
	my_array=(available_frequencies max_freq target_freq available_governors min_freq trans_stat cur_freq polling_interval uevent device power governor subsystem) #需要修改
	for tempdata in ${my_array[@]}
	do
		echo ${tempdata}
		grep ${tempdata} ${tempfile}
		if [ $? -eq 0 ]
		then
			log info "The interface is normal"
		else
			log error "${Tag} step2 Fail"
			return 0
		fi
	done
	log info "${Tag} test Pass"
	}
#**********devfreq_4———available_frequencies接口可以正常查看支持哪些频率*****
devfreq_4(){
	Tag = devfreq_4
	array=(762 1525 3051 4066)
	interfreq $Tag "available_frequencies" $array 
	}
#**********devfreq_5———available_governors接口可以正常查看支持哪些频率*****
devfreq_5(){
	Tag = devfreq_5
	array=(jlq_bwmon userspace powersave performance)
	interfreq $Tag "available_governors" $array 
	}
#**********devfreq_6———max_freq接口可以正常显示支持最高频率*****
devfreq_6(){
	Tag = devfreq_6
	array=(4066)
	interfreq $Tag "max_freq" $array 
	}
#**********devfreq_7———min_freq接口可以正常显示支持最低频率*****
devfreq_7(){
	Tag = devfreq_7
	array=(762)
	interfreq $Tag "min_freq" $array 
	}
#**********devfreq_8———target_freq接口可以正常显示目标频率*****NOT自动化
#**********devfreq_9———trans_stat接口可以正常显示各频率下维持时间*****NOT自动化
#**********devfreq_10———cur_freq接口可以正常显示当前频率*****NOT自动化
#**********devfreq_11———polling_interval接口可以正常显示轮询间隔时间*****
devfreq_11(){
	Tag = devfreq_11
	array=(50)
	interfreq $Tag "polling_interval" $array 
	}
#**********devfreq_12———uevent接口可以正常显示内核模块的热插拔事件的通知*****NOT自动化
#**********devfreq_13———power查询电源状态*****NOT自动化
#**********devfreq_14———device指向当前节点和其他节点*****NOT自动化
#**********devfreq_15———subsystem指向子系统节点*****NOT自动化
#*********devfreq_16————检查设置jlq_bwmon为当前调频策略*********
devfreq_16(){
	Tag=devfreq_16
	setfreq $Tag jlq_bwmon
}
#**********devfreq_17————检查设置powersave为当前调频策略*********
devfreq_17(){
	Tag=devfreq_17
	setfreq $Tag powersave
}
#**********devfreq_18————检查设置performance为当前调频策略*********
devfreq_18(){
	Tag=devfreq_18
	setfreq $Tag powersave
}
#**********devfreq_19————检查设置userspace为当前调频策略边界测试_设置频率为小于1的值************这是一个异常测试用例
devfreq_19(){
	Tag = devfreq_19
	userfreq $Tag 0
	 
}
#**********devfreq_20————检查设置userspace为当前调频策略边界测试_设置频率为小于762大于0的值****
devfreq_20(){
	Tag = devfreq_20
	userfreq $Tag 1
}
#**********devfreq_21————检查设置userspace为当前调频策略边界测试_设置频率为762****************
devfreq_21(){
	Tag = devfreq_21
	userfreq $Tag 762
}
#**********devfreq_22————检查设置userspace为当前调频策略边界测试_设置频率为3051***************
devfreq_22(){
	Tag = devfreq_22
	userfreq $Tag 3051
}
#**********devfreq_23————检查设置userspace为当前调频策略边界测试_设置频率为4066***************
devfreq_23(){
	Tag = devfreq_23
	userfreq $Tag 4066
}
#**********devfreq_24————检查设置userspace为当前调频策略边界测试_设置频率为1525***************
devfreq_24(){
	Tag = devfreq_24
	userfreq $Tag 1525
}
#**********devfreq_25————检查设置userspace为当前调频策略边界测试_设置频率为大于762小于1525****
devfreq_25(){
	Tag = devfreq_21
	userfreq $Tag 1000
}
#**********devfreq_26————检查设置userspace为当前调频策略边界测试_设置频率为大于1525小于3051***
devfreq_26(){
	Tag = devfreq_22
	userfreq $Tag 2000
}
#**********devfreq_27————检查设置userspace为当前调频策略边界测试_设置频率为大于3051小于4066****
devfreq_27(){
	Tag = devfreq_23
	userfreq $Tag 4000
}
#**********devfreq_28————检查设置userspace为当前调频策略边界测试_设置频率为大于4066************
devfreq_28(){
	Tag = devfreq_25
	userfreq $Tag 4067
}
#**********devfreq_29————不同策略之间切换1000次查看是否死机等异常************
devfreq_29(){
	Tag = devfreq_29
	for((times=1;times<=1000;times++));
	do
		第一步：设置不同的调频状态
		arr_freq=(jlq_bwmon powersave performance userspace)
		for freq in ${arr_freq[@]}
		do
			adb shell "echo $freq > /sys/class/devfreq/devfreq0/governor"
			if [ $? -eq 1 ]
			then
				log error "$Tag step1 Fail"
				return 0	
			fi
		done
	done
	log info "$Tag test Pass"
#**********devfreq_30————不同userspace频率段之间切换之间切换1000次查看是否死机等异常************
devfreq_30(){
	Tag = devfreq_30
	adb shell "echo userspace > /sys/class/devfreq/devfreq0/governor"
	for((times=1;times<=1000;times++));
	do
		第一步：设置不同userspace频率
		arr_freq=(0 760 780 1525 1530 3051 3088 4066 4089)
		for freq in ${arr_freq[@]}
		do
			adb shell"echo $freq > /sys/class/devfreq/devfreq0/userspace/set_freq"
			if [ $? -eq 1 ]
			then
				log error "$Tag step1 Fail"
				return 0	
			fi
		done
	done
	log info "$Tag test Pass"

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
arr_fun=(devfreq_2 devfreq_3 devfreq_4 devfreq_5 devfreq_6 devfreq_7 devfreq_11 devfreq_16 devfreq_17 devfreq_18 devfreq_19 devfreq_20 devfreq_21 devfreq_22 devfreq_23 devfreq_24 devfreq_25)  #需要测试的测试用例
for fun in ${arr_fun[@]}
do
	${fun}
done
log info "done"
#********************导出测试报告******************************************
report="./logout"/"result"_$(date -d "today" +"%Y%m%d_%H%M%S").log  #定义测试报告输出文件
report 2>&1 |tee -a $report
