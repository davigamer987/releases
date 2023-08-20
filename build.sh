#!/bin/bash
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=/mnt/ccache
ccache -M 50G -F 0
export outdir="/home/davi/releases/android/out/target/product/${device}"
BUILD_START=$(date +"%s")
echo "Build started for ${device}"
if [ "${jenkins}" == "true" ]; then
    telegram -M "Build ${BUILD_DISPLAY_NAME} started for ${device}: [See Progress](${BUILD_URL}console)"
else
    telegram -M "Build started for ${device}"
fi
source build/envsetup.sh
source "${my_dir}/config.sh"
if [ "${official}" == "true" ]; then
    export CUSTOM_BUILD_TYPE="OFFICIAL"
fi
if [ -z "${buildtype}" ]; then
    export buildtype="userdebug"
fi
if [ "${ccache}" == "true" ] && [ -n "${ccache_size}" ]; then
    export USE_CCACHE=1
    ccache -M "${ccache_size}G"
elif [ "${ccache}" == "true" ] && [ -z "${ccache_size}" ]; then
    echo "Please set the ccache_size variable in your config."
    exit 1
fi
if [ ! -z "${rom_vendor_name}" ]; then
    lunch "${rom_vendor_name}_${device}-${buildtype}"
else
    lunch "${device}-${buildtype}"
fi
if [ "${clean}" == "clean" ]; then
    m clean -j$(nproc --all)
elif [ "${clean}" == "installclean" ]; then
    m installclean -j$(nproc --all)
    rm -rf out/target/product/"${device}"/obj/DTBO_OBJ
else
    rm "${outdir}"/*$(date +%Y)*.zip*
fi
sh /home/davi/releases/per.sh & PIDIOS=$!
m "${bacon}" -j$(nproc --all)
buildsuccessful="${?}"
wait $PIDIOS
curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data message_id=553 --data text=No_Build --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageText
BUILD_END=$(date +"%s")
BUILD_DIFF=$((BUILD_END - BUILD_START))

if [ "${generate_incremental}" == "true" ]; then
    if [ -e "${ROM_DIR}"/*"${device}"*target_files*.zip ]; then
        export old_target_files_exists=true
        export old_target_files_path=$(ls "${ROM_DIR}"/*"${device}"*target_files*.zip | tail -n -1)
    else
        echo "Old target-files package not found, generating incremental package on next build"
    fi
    export new_target_files_path=$(ls "${outdir}"/obj/PACKAGING/target_files_intermediates/*target_files*.zip | tail -n -1)
    if [ "${old_target_files_exists}" == "true" ]; then
        ota_from_target_files -i "${old_target_files_path}" "${new_target_files_path}" "${outdir}"/incremental_ota_update.zip
        export incremental_zip_path=$(ls "${outdir}"/incremental_ota_update.zip | tail -n -1)
    fi
    cp "${new_target_files_path}" "${ROM_DIR}"
fi
    cd /home/davi/releases/android/out/target/product/TP1803
    echo "using device sys $(pwd)"
    export zip_name=$(find -type f -name "*${device}*.zip" -exec stat -c '%Y %n' {} \; | sort -nr | head -n 20 | awk 'NR==1,NR==1 {print $2}')
    export zip_name=$(basename "${rom_name}")
    export finalzip_path="/home/davi/releases/android/out/target/product/${device}/${zip_name}"
    ROM_SIZE=$(ls -lh "${finalzip_path}" | cut -f5 -d " ")
fi
if [ "${upload_recovery}" == "true" ]; then
    if [ ! -e "${outdir}"/recovery.img ]; then
        cp "${outdir}"/boot.img "${outdir}"/recovery.img
    fi
    export img_path=$(ls "${outdir}"/recovery.img | tail -n -1)
fi
export tag=$( echo "$(date +%Y%m%d%H%M)-${zip_name}" | sed 's|.zip||')
if [ "${buildsuccessful}" == "0" ] && [ ! -z "${finalzip_path}" ]; then
    echo "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"

    echo "Uploading"
    GH_TAG="${ROM}-${ROM_VERSION}-${device}-$(date +"%Y-%m-%d")"
    echo "Final zip path: ${finalzip_path}"
    gh release create "${GH_TAG}" -t "${ROM}-${device}: $(date +"%Y-%m-%d")" -n "New Build for ${device}" "${ROM_ZIP}"
    github-release "${release_repo}" "${tag}" "master" "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${finalzip_path}"
    if [ "${generate_incremental}" == "true" ]; then
        if [ -e "${incremental_zip_path}" ] && [ "${old_target_files_exists}" == "true" ]; then
            github-release "${release_repo}" "${tag}" "master" "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${incremental_zip_path}"
        elif [ ! -e "${incremental_zip_path}" ] && [ "${old_target_files_exists}" == "true" ]; then
            echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
            exit 1
        fi
    fi
    if [ "${upload_recovery}" == "true" ]; then
        if [ -e "${img_path}" ]; then
            github-release ${release_repo} ${tag} master "${ROM} for ${device}

Date: $(env TZ="${timezone}" date)" "${img_path}"
        else
            echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
            curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
            exit 1
        fi
    fi
    echo "Uploaded"

    if [ "${upload_recovery}" == "true" ]; then
        if [ "${old_target_files_exists}" == "true" ]; then
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download ROM: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download incremental update: ["incremental_ota_update.zip"]("https://github.com/${release_repo}/releases/download/${tag}/incremental_ota_update.zip")
Download recovery: ["recovery.img"]("https://github.com/${release_repo}/releases/download/${tag}/recovery.img")"
        else
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download ROM: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download recovery: ["recovery.img"]("https://github.com/${release_repo}/releases/download/${tag}/recovery.img")"
        fi
    else
        if [ "${old_target_files_exists}" == "true" ]; then
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Download incremental update: ["incremental_ota_update.zip"]("https://github.com/${release_repo}/releases/download/${tag}/incremental_ota_update.zip")"
        else
            telegram -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds
👤 by @davigamer987
📅 Build date: $(date +"%d-%m-%Y")
📎 File size: ${ROM_SIZE}
Download: ["${zip_name}"]("https://github.com/${release_repo}/releases/download/${tag}/${zip_name}")
Gdrive Download: ["${zip_name}"]("https://drive.realmeme.ml/0:/${zip_name}")"
        fi
    fi
curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker

else
    echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
    telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
    curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
    exit 1
fi
