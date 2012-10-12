# Cookbook Name:: ceph
# Recipe:: config 
#
# Author:: Kyle Bader <kyle.bader@dreamhost.com>
# Author:: Carl Perry <carl.perry@dreamhost.com>
#
# Copyright 2011, 2012 DreamHost Web Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

execute "start ceph services" do
  command "service ceph start"
  returns [0,1]
  action :nothing
end

# Grab any OSD devices on this node
osd_devices = []
if (! node['ceph']['osd_devices'].nil?) then
  node['ceph']['osd_devices'].each do |osd_device|
    if (! osd_device['osd_id'].nil?)
      osd_devices << osd_device
    end
  end
end

# Get monitor ips and hostnames
monitors = {}
mon_pool = search(:node, "roles:ceph-mon AND chef_environment:#{node.chef_environment}")
mon_pool.each do |monitor|
  monitors[monitor['hostname']] = get_if_ip_for_net("storage",monitor)
end

# Get storage ips if I'm an OSD
storage_ip = ''
storage_back_ip = ''
node.run_list.each do |matching|
  if (matching == 'role[ceph-osd]')
    storage_ip = get_if_ip_for_net("storage",node)
    storage_back_ip = get_if_ip_for_net("storage-back",node)
  end
end

# Am I a RESTful RADOS Gateway?
is_radosgw = 0
node.run_list.each do |matching|
  if (matching == "role[ceph-rgw]")
    is_radosgw = 1
  end
end

directory "/etc/ceph" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

template '/etc/ceph/ceph.conf' do
  source 'ceph.conf.erb'
  variables(
            :monitors => monitors,
            :osd_devices => osd_devices,
            :storage_ip => storage_ip,
            :storage_back_ip => storage_back_ip,
            :is_radosgw => is_radosgw
  )
  mode '0644'
  notifies :run, resources(:execute => "start ceph services")
end

