#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, edelight GmbH
# Authors:
#       Markus Korn <markus.korn@edelight.de>
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
#

# mongo-10gen-server package depends on mongo-10gen, but doesn't get upgraded.
# This forces an explict upgrade.
if !node[:mongodb][:override_install]
  if (node[:mongodb][:package_name] == "mongo-10gen-server")
    package "mongo-10gen" do
      action :install
      version node[:mongodb][:package_version]
      source node[:mongodb][:localrpm_server]
    end
  end

  package node[:mongodb][:package_name] do
    action :install
    version node[:mongodb][:package_version]
    source node[:mongodb][:localrpm_client]
  end
end

needs_mongo_gem = (node.recipes.include?("mongodb::replicaset") or node.recipes.include?("mongodb::mongos"))

# install the mongo ruby gem at compile time to make it globally available
if needs_mongo_gem
  current_version = Gem::Version.new(Chef::VERSION)
  if(current_version < Gem::Version.new('10.12.0'))
    gem_package 'mongo' do
      action :nothing
    end.run_action(:install)
    Gem.clear_paths
  else
    chef_gem 'mongo' do
      action :install
    end
  end
end

# allow mongodb_instance to run if recipe isn't included
allow_mongodb_instance_run = true
conflicting_recipes = %w(mongodb::replicaset mongodb::shard mongodb::configserver mongodb::mongos mongodb::mms_agent)
chef_major_version = Chef::VERSION.split('.').first.to_i
if chef_major_version < 11
  conflicting_recipes.each do |recipe|
    allow_mongodb_instance_run &&= false if node.recipe?(recipe)
  end
else
  conflicting_recipes.each do |recipe|
    allow_mongodb_instance_run &&= false if node.run_context.loaded_recipe?(recipe)
  end
end

if allow_mongodb_instance_run
  # configure default instance
  mongodb_instance "mongodb" do
    mongodb_type "mongod"
    bind_ip      node['mongodb']['bind_ip']
    port         node['mongodb']['port']
    logpath      node['mongodb']['logpath']
    dbpath       node['mongodb']['dbpath']
    enable_rest  node['mongodb']['enable_rest']
    smallfiles   node['mongodb']['smallfiles']
    noprealloc   node['mongodb']['noprealloc']
  end
end
