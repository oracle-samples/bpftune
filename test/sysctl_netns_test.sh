#!/usr/bin/bash
#
# SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note
#
# Copyright (c) 2023, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License v2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 021110-1307, USA.
#

# run sysctl test

PORT=5201

. ./test_lib.sh

SLEEPTIME=5
TIMEOUT=30

for TUNER in neigh_table ; do

   test_start "$0|sysctl test: does setting sysctl switch off tuner in netns only?"

   rmem_orig=($(sysctl -n net.ipv4.tcp_rmem))

   sysctl -qw net.ipv4.tcp_rmem="${rmem_orig[0]} ${rmem_orig[1]} ${rmem_orig[1]}"

   test_run_cmd_local "$BPFTUNE -ds &" true

   sleep $SETUPTIME

   # need to setup netns after bpftune starts...
   test_setup "true"

   if [[ ${BPFTUNE_NETNS} -eq 0 ]]; then
        echo "bpftune does not support per-netns policy, skipping..."
        test_pass
   fi

   rmem_orig_netns=($(ip netns exec $NETNS sysctl -n net.ipv4.tcp_rmem))

   for SYSCTL in kernel.core_pattern net.ipv4.tcp_rmem ; do
	val=$(ip netns exec $NETNS sysctl -qn $SYSCTL)
	ip netns exec $NETNS sysctl -qw ${SYSCTL}="${val}"
   done
   sleep $SLEEPTIME
   grep "modified sysctl" $TESTLOG_LAST
   grep "setting state of netns" $TESTLOG_LAST

   ADDR=$VETH1_IPV4

   test_run_cmd_local "ip netns exec $NETNS $IPERF3 -s -p $PORT -1 &"
   sleep $SLEEPTIME
   test_run_cmd_local "$IPERF3 -fm -p $PORT -c $ADDR" true
   sleep $SLEEPTIME

   rmem_post=($(sysctl -n net.ipv4.tcp_rmem))
   rmem_post_netns=($(ip netns exec $NETNS sysctl -n net.ipv4.tcp_rmem))
   if [[ "${rmem_post[2]}" -gt ${rmem_orig[1]} ]]; then
   	echo "rmem before ${rmem_orig[1]} ; after ${rmem_post[2]}"
	echo "netns rmem before ${rmem_orig_netns[2]} ; after ${rmem_post_netns[2]}"
	if [[ "${rmem_post_netns[2]}" -gt ${rmem_orig_netns[2]} ]]; then
		test_cleanup
	fi
   else
	test_cleanup
   fi

   test_pass

   test_cleanup
done

test_exit
