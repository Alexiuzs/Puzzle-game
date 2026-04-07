# word_puzzle






## Web release
>>increment build number in pubspec.yaml
```
rm -rf build/web
flutter build web 
cd build/web
HASH=$( (cat main.dart.js; date +%s) | sha256sum | cut -c1-8 )
mv main.dart.js main.dart.$HASH.js
sed -i .bak "s/main.dart.js/main.dart.$HASH.js/g" flutter_bootstrap.js 
rm flutter_bootstrap.js.bak 
cd ../..
```
