# AI server on calorietracker.moezzadigital.com (cPanel / PHP)

1. cPanel -> Domains (or Subdomains): note the "Document Root" folder of calorietracker.moezzadigital.com.
2. File Manager -> Settings -> tick "Show Hidden Files".
3. Open that Document Root folder -> create folder `api`.
4. Upload analyze.php, coach.php and .htaccess into that `api` folder.
5. Go to your home folder (top of File Manager, where you see public_html). Upload aicc-config.php there.
6. Edit aicc-config.php there and paste your Gemini key. Save.
7. Test: https://calorietracker.moezzadigital.com/api/analyze.php should show {"error":"Use POST."}
