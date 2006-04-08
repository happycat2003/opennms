#!/bin/sh -
#
# chkconfig: 345 99 01
# description: Starts and stops the OpenNMS network management \
#              poller and backend processes
# processname: opennms
# pidfile: @install.pid.file@
#
### BEGIN INIT INFO
# Provides:          opennms
# Required-Start:    $local_fs $network @install.postgresql.service@
# Should-Start:      $time $named ypbind
# Required-Stop:     $local_fs $network
# Should-Stop:       $time $named ypbind
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: OpenNMS daemon for network monitoring
# Description:       OpenNMS daemon for network monitoring
### END INIT INFO
#
#  $Id$
#
#  For info on the "chkconfig:" section, see:
#      http://www.sensi.org/~alec/unix/redhat/sysvinit.html
#
#  For info on the "BEGIN INIT INFO" section, see:
#      http://www.suse.de/~mmj/Package-Conventions/
#
# Modifications:
#
# 2005 Oct 01: Removed `date` from a few echo commands and redirected
#              a few error messages to stderr. -- DJ Gregor
#

#### ------------> DO NOT CHANGE VARIABLES IN THIS FILE <------------- ####
#### Create $OPENNMS_HOME/etc/opennms.conf and put overrides in there. ####
#### ------------> DO NOT CHANGE VARIABLES IN THIS FILE <------------- ####

# Home directory for OpenNMS.
OPENNMS_HOME="@install.dir@"

# PID file for OpenNMS.
OPENNMS_PIDFILE="@install.pid.file@"

# Log directory for OpenNMS
LOG_DIRECTORY="@install.logs.dir@"

# Directory where init functions are likely stored (we also check a few other
# directories, just in case)
INITDIR="@install.init.dir@"

# Where to redirect "start" output.
REDIRECT="$LOG_DIRECTORY/output.log"

# Number of times to do "opennms status" after starting OpenNMS to see
# if it comes up completely.  Set to "0" to disable.  Between each
# attempt we sleep for STATUS_WAIT seconds.  
START_TIMEOUT=10

# Number of seconds to wait between each "opennms status" check when
# START_TIMEOUT > 0.
STATUS_WAIT=5

# Value of the -Xmx<size>m option passed to Java.
JAVA_HEAP_SIZE=256

# Additional options that should be passed to Java when starting OpenNMS.
ADDITIONAL_MANAGER_OPTIONS=""

# Classpath additions.  These go on the front of our classpath.
ADDITIONAL_CLASSPATH=""

# Use incremental garbage collection.
USE_INCGC=""

# Use the Java Hotspot server VM.
HOTSPOT=""

# Enable verbose garbage collection debugging.
VERBOSE_GC=""

# Additional options to pass to runjava.
RUNJAVA_OPTIONS=""

# URL that this script uses to communicate with a running OpenNMS daemon.
INVOKE_URL="http://127.0.0.1:8181/invoke?objectname=OpenNMS:Name=FastExit"

#### ------------> DO NOT CHANGE VARIABLES IN THIS FILE <------------- ####
#### Create $OPENNMS_HOME/etc/opennms.conf and put overrides in there. ####
#### ------------> DO NOT CHANGE VARIABLES IN THIS FILE <------------- ####


# Load opennms.conf, if it exists, to override above configuration options.
if [ -f $OPENNMS_HOME/etc/opennms.conf ]; then
    . $OPENNMS_HOME/etc/opennms.conf
fi

show_help () {
    cat <<END

Usage: $0 [-n] [-t] [-v] <command> [<service>]
 
  command options: start|stop|restart|status|check|pause|resume|kill

  service options: all|<a service id from the etc/service-configuration.xml>
                   defaults to all

  The following options are available:

    -n    "No execute" mode.  Don't call Java to do anything.
    -t    Test mode.  Enable JPDA on port 8001.
    -v    Verbose mode.  When used with the "status" command, gives the
          results for all OpenNMS services.  When used with "start", enables
          some verbose debugging, such as details on garbage collection.

END
    return
}

checkRpmFiles(){
    # XXX need to have a way to specify the Tomcat directory to check
    if [ -d /var/tomcat4/webapps/opennms/WEB-INF ]; then
	TOMCATDIR=/var/tomcat4/webapps/opennms/WEB-INF
    else
	TOMCATDIR=""
    fi

    if [ `find $OPENNMS_HOME $TOMCATDIR -name \*.rpmnew | wc -l` -gt 0 ]; then
	cat <<END

WARNING!  You have files that end in .rpmnew in your
OPENNMS_HOME ($OPENNMS_HOME) directory.

The format of the original files may have changed since
you modified them before installing a new version.
Please double-check that your configuration files are
up-to-date and delete any leftover .rpmnew files or
OpenNMS will not start.

END
	return 6    # From LSB: 6 - program is not configured
    fi

    if [ `find $OPENNMS_HOME $TOMCATDIR -name \*.dpkg-dist | wc -l` -gt 0 ]; then
	cat <<END

WARNING!  You have files that end in .dpkg-dist in your
OPENNMS_HOME ($OPENNMS_HOME) directory.

The format of the original files may have changed since
you modified them before installing a new version.
Please double-check that your configuration files are
up-to-date and delete any leftover .dpkg-dist files or
OpenNMS will not start.

END
	return 6    # From LSB: 6 - program is not configured
    fi

    if [ `find $OPENNMS_HOME $TOMCATDIR -name \*.rpmsave | wc -l` -gt 0 ]; then
	cat <<END

WARNING!  You have files that end in .rpmsave in your
OPENNMS_HOME ($OPENNMS_HOME) directory.

The format of the original files may have changed since
you modified them before installing a new version, so
your modified configuration files have been backed up
and replaced.  Please double-check that your changes to
the configuration files are added back into the update
files and delete any leftover .rpmsave files or OpenNMS
will not start.

END
	return 6    # From LSB: 6 - program is not configured
    fi

    return 0
}

doStart(){
    checkRpmFiles || return $?

    doStatus
    status=$?
    case $status in
	0)
	    echo "OpenNMS is already running." >&2
	    return 1
	    ;;

	160)
	    echo "OpenNMS is partially running." >&2
	    echo "If you have just attempted starting OpenNMS, please try again in a few" >&2
	    echo "moments, otherwise, at least one service probably had issues starting." >&2
	    echo "Check your logs in $LOG_DIRECTORY for errors." >&2
	    return 1
	    ;;

	3)
	    true  # don't do anything, it isn't running, which is good 
	          # because we are going to start it. :-)
	    break
	    ;;

	*)
	    echo "Unknown value return from doStatus: $status" >&2
	    return 1
    esac


    $JAVA_CMD -Dopennms.home=$OPENNMS_HOME -jar $BOOTSTRAP check
    if [ $? -ne 0 ]; then
	echo "OpenNMS runs better if you start up the database first." >&2
	return 1
    fi

    ##########################################################################
    # Run opennms.sh with the "-t" option to enable the Java Platform Debugging
    # Architecture. This will open a server socket on port 8001 that can be
    # connected to by a remote java debugger. A good choice is JSwat which can 
    # be found at http://www.bluemarsh.com
    ###########################################################################
    if [ $TEST -gt 0 ]; then
	echo "- enabling JPDA debugging on port 8001"
	JPDA="-Xdebug -Xnoagent -Djava.compiler=none -Xrunjdwp:transport=dt_socket,server=y,address=8001,suspend=n"
    else
	JPDA=""
    fi


    if [ "$SERVICE" = "" ]; then
	APP_VM_PARMS="$JPDA $MANAGER_OPTIONS"
	APP_PARMS_BEFORE="start"

    else
	APP_VM_PARMS="$CONTROLLER_OPTIONS"
	APP_PARMS_BEFORE="start $SERVICE"
    fi

    if [ -z "$NOEXECUTE" ]; then
	echo "------------------------------------------------------------------------------" >> "$REDIRECT"
	date >> "$REDIRECT"
	echo "begin ulimit settings:" >> "$REDIRECT"
	ulimit -a >> "$REDIRECT"
	echo "end ulimit settings" >> "$REDIRECT"
	CMD="$JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER"
	echo "Executing command: $CMD" >> "$REDIRECT"
	$CMD >>"$REDIRECT" 2>&1 &
	echo $! > "$OPENNMS_PIDFILE"
	# disown # XXX specific to bash
    fi

    if [ $START_TIMEOUT -eq 0 ]; then
	# don't wait for OpenNMS to startup
	$opennms_echo "(not waiting for startup) \c"
	return 0
    fi

    # wait for OpenNMS to startup
    STATUS_ATTEMPTS=0
    while [ $STATUS_ATTEMPTS -lt $START_TIMEOUT ]; do
	if doStatus; then
	    return 0
	fi
	sleep $STATUS_WAIT
	STATUS_ATTEMPTS=`expr $STATUS_ATTEMPTS + 1`
    done

    echo "Started OpenNMS, but it has not finished starting up" >&2
    return 1
    
}

doPause(){
    if doStatus; then
	APP_VM_PARMS="$CONTROLLER_OPTIONS"
	APP_PARMS_BEFORE="-u $INVOKE_URL pause $SERVICE"
	if [ -z "$NOEXECUTE" ]; then
	    $JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER
	fi
    else
	echo "OpenNMS is not running."
    fi
}

doResume(){
    if doStatus; then
	APP_VM_PARMS="$CONTROLLER_OPTIONS"
	APP_PARMS_BEFORE="-u $INVOKE_URL resume $SERVICE"
	if [ -z "$NOEXECUTE" ]; then
	    $JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER
	fi
    else
	echo "OpenNMS is not running."
    fi
}

doCheck() {
    if doStatus; then
	# do nothing.. it's running
	exit 0
    fi

    echo "OpenNMS is not running... Restarting" >&2
    $OPENNMS_HOME/bin/opennms.sh start

    exit 1
}

doStop() {
    doStatus
    if [ $? -eq 3 ]; then
	echo "Trying to stop OpenNMS but it's already stopped." >&2
	return 7   # LSB says: 7 - program is not running
    fi

    STOP_ATTEMPTS=0
    while [ $STOP_ATTEMPTS -lt 5 ]; do
	doStatus
	if [ $? -eq 3 ]; then
	    echo "" > "$OPENNMS_PIDFILE"
	    return 0
	fi

	if [ -z "$NOEXECUTE" ]; then
	    APP_VM_PARMS="$CONTROLLER_OPTIONS"
	    APP_PARMS_BEFORE="-u $INVOKE_URL stop $SERVICE"
	    $JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER
	fi

	sleep 5

	STOP_ATTEMPTS=`expr $STOP_ATTEMPTS + 1`
    done

    return 1
}

doKill(){
    if doStatus; then
	APP_VM_PARMS="$CONTROLLER_OPTIONS"
	APP_PARMS_BEFORE="-u $INVOKE_URL exit"
	$JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER
    fi

    pid="`test -f $OPENNMS_PIDFILE && cat $OPENNMS_PIDFILE`"
    if [ x"$pid" != x"" ]; then
	if ps -p "$pid" | grep "^root" > /dev/null; then
	    kill -9 $pid > /dev/null 2>&1
	fi
    fi

    echo "" > "$OPENNMS_PIDFILE"
}

doStatus(){
    if [ $VERBOSE -gt 0 ]; then
	STATUS_VERBOSE="-v"
    else
	STATUS_VERBOSE=""
    fi

    if [ -z "$NOEXECUTE" ]; then
	APP_VM_PARMS="$CONTROLLER_OPTIONS"
	APP_PARMS_BEFORE="-u $INVOKE_URL $STATUS_VERBOSE status"
	$JAVA_CMD $APP_VM_PARMS -jar $BOOTSTRAP $APP_PARMS_BEFORE "$@" $APP_PARMS_AFTER
    fi
}

FUNCTIONS_LOADED=0

if [ -f /etc/SuSE-release ]; then
    . /etc/rc.status
    rc_reset
else
    # Source function library.
    for dir in "$INITDIR" /etc /etc/rc.d; do
	if [ -f "$dir/init.d/functions" -a $FUNCTIONS_LOADED -eq 0 ]; then
	    . "$dir/init.d/functions"
	    FUNCTIONS_LOADED=1
	fi
    done
fi

if [ `echo "\000\c" | wc -c` -eq 1 ]; then
    opennms_echo="echo"
elif [ `echo -e "\000\c" | wc -c` -eq 1 ]; then
    opennms_echo="echo -e"
else
    echo "ERROR: could not get 'echo' to emit just a null character" >&2
    exit 1
fi

ulimit -s 8192 > /dev/null 2>&1
ulimit -n 10240 > /dev/null 2>&1
if [ x"`uname`" = x"Darwin" ]; then
    for flag in "-d" "-f" "-l" "-m" "-n" "-s" "-u" "-v"; do
	ulimit $flag unlimited >/dev/null 2>&1
    done
fi

umask 002

# XXX is this needed?  maybe we should "cd $OPENNMS_HOME/logs" so hotspot
# XXX error files go somewhere reasonable
cd "$OPENNMS_HOME" || { echo "could not \"cd $OPENNMS_HOME\"" >&2; exit 1; }

# define needed for grep to find opennms easily
JAVA_CMD="$OPENNMS_HOME/bin/runjava -r $RUNJAVA_OPTIONS --"

#
#if [ x"$ADDITIONAL_CLASSPATH" != x"" ]; then
#    APP_CLASSPATH="$ADDITIONAL_CLASSPATH:$OPENNMS_HOME/etc"
#else
#    APP_CLASSPATH="$OPENNMS_HOME/etc"
#fi
#for jar in $OPENNMS_HOME/lib/*.jar; do
#    APP_CLASSPATH="$APP_CLASSPATH:$jar"
#done
#

BOOTSTRAP="$OPENNMS_HOME/lib/opennms_bootstrap.jar"

#MANAGER_OPTIONS="-DOPENNMSLAUNCH"
MANAGER_OPTIONS=""
MANAGER_OPTIONS="$MANAGER_OPTIONS -Dopennms.home=$OPENNMS_HOME"
#MANAGER_OPTIONS="$MANAGER_OPTIONS -Djcifs.properties=$OPENNMS_HOME/etc/jcifs.properties"
MANAGER_OPTIONS="$MANAGER_OPTIONS -Xmx${JAVA_HEAP_SIZE}m"

if [ -n "$USE_INCGC" -a "$USE_INCGC" = true ] ; then
    MANAGER_OPTIONS="$MANAGER_OPTIONS -Xincgc"
fi

if [ x"$ADDITIONAL_MANAGER_OPTIONS" != x"" ]; then
    MANAGER_OPTIONS="$MANAGER_OPTIONS $ADDITIONAL_MANAGER_OPTIONS"
fi


if [ -n "$HOTSPOT" -a "$HOTSPOT" = true ] ; then
    JAVA_CMD="$JAVA_CMD -server"
fi

CONTROLLER_OPTIONS="-Dopennms.home=$OPENNMS_HOME"
#CONTROLLER_OPTIONS="$CONTROLLER_OPTIONS -Dlog4j.configuration=log4j.properties"

TEST=0
NOEXECUTE=""
VERBOSE=0

NAME="opennms"

while getopts ntv c; do
    case $c in
	n)
	    NOEXECUTE="foo"
	    ;;
	t)
	    TEST=1
	    ;;
	v)
	    VERBOSE=1
	    VERBOSE_GC=1
	    ;;

	"?")
	    show_help
	    exit 1
	    ;;
    esac
done
shift `expr $OPTIND - 1`

if [ $# -eq 0 ]; then
    show_help
    exit 1
else
    COMMAND="$1"; shift
fi

if [ $# -gt 0 ]; then
    SERVICE="$1"; shift
else
    SERVICE=""
fi

if [ $# -gt 0 ]; then
    show_help
    exit 1
fi

if [ x"$SERVICE" = x"all" ]; then
    SERVICE=""
fi

if [ x"$VERBOSE_GC" != x"" ]; then
    MANAGER_OPTIONS="$MANAGER_OPTIONS -verbose:gc"
fi

if [ ! -f $OPENNMS_HOME/etc/configured ]; then
    echo "$0: OpenNMS not configured." >&2
    echo "$OPENNMS_HOME/etc/configured does not exist." >&2
    echo "You need to run the installer to setup the database -- see the" >&2
    echo "install guide for details." >&2
    exit 6    # From LSB: 6 - program is not configured
fi

if id | grep '^uid=0(' > /dev/null; then
    true # all is well
else
    echo "Error: you must run this script as root" >&2
    exit 4    # According to LSB: 4 - user had insufficient privileges
fi

case "$COMMAND" in
    start|spawn)
	$opennms_echo "Starting OpenNMS: \c"

	if [ -f /etc/SuSE-release ]; then
	    doStart

	    # Remember status and be verbose
	    rc_status -v
	elif [ $FUNCTIONS_LOADED -ne 0 ]; then
	    doStart
	    ret=$?
	    if [ $ret -eq 0 ]; then
		echo_success
		touch /var/lock/subsys/${NAME}
	    else
		echo_failure
	    fi
	    echo ""
	else
	    doStart
	    ret=$?
	    if [ $ret -eq 0 ]; then
		echo "ok"
	    else
		echo "failed"
	    fi
	fi
	;;

    stop)
	$opennms_echo "Stopping OpenNMS: \c"
	if [ -f /etc/SuSE-release ]; then
	    doStop

	    # Remember status and be verbose
	    rc_status -v

	    doKill
	elif [ $FUNCTIONS_LOADED -ne 0 ]; then
	    doStop
	    ret=$?
	    if [ $ret -eq 0 ]; then
		echo_success
	    else
		echo_failure
	    fi
	    rm -f /var/lock/subsys/${NAME}
	    echo ""

	    doKill
	else
	    doStop
	    ret=$?
	    if [ $ret -eq 0 ]; then
		echo "stopped"
	    else
		echo "failed"
	    fi

	    doKill
	fi
	;;

    restart)
        ## Stop the service and regardless of whether it was
        ## running or not, start it again.
	$OPENNMS_HOME/bin/opennms.sh stop
	$OPENNMS_HOME/bin/opennms.sh start
	ret=$?

	if [ -f /etc/SuSE-release ]; then
	    rc_failed $ret
	fi
	;;

    status)
	if [ -f /etc/SuSE-release ]; then
	    $opennms_echo "Checking for OpenNMS: \c"
	    if [ $VERBOSE -gt 0 ]; then
		echo ""
	    fi
	    doStatus

	    # Remember status and be verbose
	    rc_status -v
	else
	    doStatus
	    ret=$?
	    case $ret in
		0)
		    echo "${NAME} is running"
		    ;;

		3)
		    echo "${NAME} is stopped"
		    ;;

		160)
		    echo "${NAME} is partially running"
		    ;;

		*)
		    echo "Unknown return code from doStatus: $ret" >&2
	    esac
	fi
	;;

    pause)
	doPause
	;;

    check)
	doCheck
	;;

    resume)
	doResume
	;;

    kill)
	doKill
	;;

    *)
	echo ""
	echo "ERROR: unknown command \"$COMMAND\""
	show_help
	exit 1
	;;
esac


if [ -f /etc/SuSE-release ]; then
    rc_exit
else
    exit $ret
fi
