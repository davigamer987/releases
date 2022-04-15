while true
do  
   export tgid=$(curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data message_id=553 --data text=Waiting --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage | grep -Eo '"message_id".*"sender_chat"' | grep -Eo '[0-9]{1,4}')
   num1=$(protoc --decode_raw < ~/releases/android/out/build_progress.pb | cut -c 4- | head -1)
   num2=$(protoc --decode_raw < ~/releases/android/out/build_progress.pb | cut -b 4-  | head -n 2 | tail -n 1)
   export per="$(echo "scale=2; $num2 / $num1*100" | bc)"
   curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data message_id=$tgid --data text=$per+% --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageText
   if [ "$num1" = "$num2" ]; then
     break
   fi
  sleep 170  
done