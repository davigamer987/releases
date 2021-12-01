#!/bin/bash
export my_dir=$(pwd)
read -p "Enter Manifest Url: " x_manifest_url
export manifest_url=$x_manifest_url
read -p "Enter Rom Vendor Name : " x_vendor_name
export rom_vendor_name=$x_vendor_name
read -p "Enter Branch Name : " x_branch_name
export branch=$x_branch_name
read -p "Enter Rom Name : " x_rom_name
export ROM=$x_rom_name
export ROM_VERSION=$x_rom_name A12
read -p "Enter Make Command Type (Eg, bacon) : " x_make_type
export bacon=$x_make_type
echo "Starting real build now Sur"
source "${my_dir}"/init.sh

