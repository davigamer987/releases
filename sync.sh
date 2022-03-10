#!/bin/bash
echo "Sync started for ${manifest_url}/tree/${branch}"
if [ "${jenkins}" == "true" ]; then
    telegram -M "Sync started for [${ROM} ${ROM_VERSION}](${manifest_url}/tree/${branch}): [See Progress](${BUILD_URL}console)"
else
    telegram -M "Sync started for [${ROM} ${ROM_VERSION}](${manifest_url}/tree/${branch})"
fi
SYNC_START=$(date +"%s")
repo init -u "${manifest_url}" -b "${branch}" --depth 1
if [ "${official}" != "true" ]; then
    rm -rf .repo/local_manifests
    mkdir -p .repo/local_manifests
    wget "${local_manifest_url}" -O .repo/local_manifests/manifest.xml
fi
cores=$(nproc --all)
if [ "${cores}" -gt "8" ]; then
    cores=8
fi
repo sync --force-sync --fail-fast --no-tags --no-clone-bundle --optimized-fetch --prune "-j${cores}" -c -v
syncsuccessful="${?}"
SYNC_END=$(date +"%s")
SYNC_DIFF=$((SYNC_END - SYNC_START))
if [ "${syncsuccessful}" == "0" ]; then
    echo "Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    export rom_vendor_name=$(echo vendor/*/config/common.mk |cut -d / -f 2 )
    sed -i "s+android.hardware.power-ndk_platform+android.hardware.power-V1-ndk_platform+g" hardware/qcom-caf/sm8150/audio/hal/Android.mk
    telegram -N -M "Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    cd device/nubia/TP1803
    mv lineage_TP1803.mk ${rom_vendor_name}_TP1803.mk
    sed -i "s+lineage+$rom_vendor_name+g" ${rom_vendor_name}_TP1803.mk
    sed -i "s+lineage+$rom_vendor_name+g" AndroidProducts.mk
    echo "BUILD_BROKEN_ENFORCE_SYSPROP_OWNER := true" >> BoardConfig.mk
    echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES := true " >> BoardConfig.mk
    echo "BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true" >> BoardConfig.mk
    cd ..
    cd ..
    cd ..
    rm -rf hardware/qcom-caf/sm8150/audio;rm -rf hardware/qcom-caf/sm8150/display
    git clone https://github.com/aospExtended/platform_hardware_qcom_audio -b 12.x-caf-sm8150 hardware/qcom-caf/sm8150/audio
    git clone https://github.com/aospExtended/platform_hardware_qcom_display -b 12.x-caf-sm8150 hardware/qcom-caf/sm8150/display
    sed -i "s+android.hardware.power-ndk_platform+android.hardware.power-V1-ndk_platform+g" hardware/qcom-caf/sm8150/audio/hal/Android.mk
    cp -R vendor/qcom/opensource/commonsys-intf vendor/qcom/opensource/commonsys
    export RELAX_USES_LIBRARY_CHECK=true
    rm device/tadiphone-fw/fw/abl.elf
    cp $my_dir/abl.v2.elf device/tadiphone-fw/fw/abl.elf
    FILE=vendor/$rom_vendor_name/config/common_full_phone.mk
    [ -f $FILE ] && echo "$FILE exists, skipping." || sed -i "s+common_full_phone.mk+common.mk+g" device/nubia/TP1803/${rom_vendor_name}_TP1803.mk
    
    # Rom specific patches

# EvoX (Evolution X) Patches

# If git is used intead of https, Make it https so the the patches will apply 
 if [ "$manifest_url" = "git://github.com/Evolution-X/manifest" ]; then
   export manifest_url="https://github.com/Evolution-X/manifest"
    fi
   
   # Apply Patches
    if [ "$manifest_url" = "https://github.com/Evolution-X/manifest" ]; then
     cd device/nubia/TP1803
     # Change sys partition size (Needs sys resize kit, will replace with gapps debloat later)
    sed -i "s+3221225472+3640655872+g" BoardConfig.mk
    sed -i "s+55588106240+115601780736+g" BoardConfig.mk
 fi

# End of EvoX specific patches

    source "${my_dir}/build.sh"
else
    echo "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds (Press F)"
    telegram -N -M "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
    exit 1
fi
