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
    telegram -N -M "Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"

# Adapt Tree
    cd device/motorola/eqs
    mv lineage_eqs.mk ${rom_vendor_name}_eqs.mk
    sed -i "s+lineage+$rom_vendor_name+g" ${rom_vendor_name}_eqs.mk
    sed -i "s+lineage+$rom_vendor_name+g" AndroidProducts.mk
    cd ..
    cd ..
    cd ..
    FILE=vendor/$rom_vendor_name/config/common_full_phone.mk
    [ -f $FILE ] && echo "$FILE exists, skipping." || sed -i "s+common_full_phone.mk+common.mk+g" device/nubia/TP1803/${rom_vendor_name}_eqs.mk
    
# Patch: Pick needed commits for eqs

cd frameworks/opt/telephony
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/38/349338/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/39/349339/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/40/349340/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/41/349341/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/42/349342/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/43/349343/1 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_opt_telephony refs/changes/44/349344/1 && git cherry-pick FETCH_HEAD
cd ..
cd ..
cd av
    git fetch https://github.com/LineageOS/android_frameworks_av refs/changes/60/342860/2 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_av refs/changes/61/342861/2 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_av refs/changes/62/342862/4 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_av refs/changes/63/342863/4 && git cherry-pick FETCH_HEAD
    git fetch https://github.com/LineageOS/android_frameworks_av refs/changes/64/342864/2 && git cherry-pick FETCH_HEAD
cd ..
cd ..

    source "${my_dir}/build.sh"
else
    echo "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds (Press F)"
    telegram -N -M "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQADGgEAAixuhBPbSa3YLUZ8DBYE --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker
    exit 1
fi
