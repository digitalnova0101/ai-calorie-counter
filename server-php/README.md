# AI server on your own hosting (cPanel / PHP)

1. cPanel -> File Manager -> Settings -> tick "Show Hidden Files".
2. Open public_html -> create folder `api`.
3. Upload analyze.php, coach.php and .htaccess (from public_html/api) into public_html/api.
4. Go one folder UP (your home folder, where you can see public_html). Upload aicc-config.php there.
5. Edit aicc-config.php there and paste your Gemini key. Save.
6. Test: open https://YOURDOMAIN/api/analyze.php in a browser. It should show {"error":"Use POST."}
