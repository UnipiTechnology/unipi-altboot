#!/bin/sh

echo "Welcome to Unipi service mode."
echo
printf "Your device is protected, for more information see the \033]8;;https://kb.unipi.technology/passwords\033\\\\password documentation\033]8;;\033\\\\.\n"
echo "Defaults are username unipi and password from the device label."
echo
echo "To exit service mode without logging in, power cycle the device."
echo "If you did not hold service button, your main system is likely corrupted."

exec /bin/login
