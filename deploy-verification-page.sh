#!/bin/bash

# Hanapbuhay Email Verification Page Deployment Script
# This script helps deploy the email verification page for cross-device support

echo "🚀 Hanapbuhay Email Verification Page Deployment"
echo "================================================"

# Check if required files exist
if [ ! -f "web/email-verification.html" ]; then
    echo "❌ Error: email-verification.html not found in web/ directory"
    exit 1
fi

echo "📋 Available deployment options:"
echo "1. GitHub Pages (Recommended - Free)"
echo "2. Netlify (Free)"
echo "3. Vercel (Free)"
echo "4. Firebase Hosting (Free tier)"
echo "5. Manual upload to any web host"
echo ""

read -p "Choose your deployment option (1-5): " choice

case $choice in
    1)
        echo "📖 GitHub Pages Deployment Guide:"
        echo "=================================="
        echo "1. Create a new PUBLIC repository on GitHub"
        echo "2. Name it: hanapbuhay-verification"
        echo "3. Upload email-verification.html and rename it to index.html"
        echo "4. Go to Settings → Pages"
        echo "5. Select 'Deploy from a branch'"
        echo "6. Choose main branch and root folder"
        echo "7. Your URL will be: https://YOUR_USERNAME.github.io/hanapbuhay-verification/"
        echo ""
        read -p "Enter your GitHub username: " github_username
        if [ ! -z "$github_username" ]; then
            echo "✅ Your verification URL will be:"
            echo "https://$github_username.github.io/hanapbuhay-verification/"
            echo ""
            echo "📝 Update this URL in lib/services/auth_service.dart:"
            echo "emailRedirectTo: 'https://$github_username.github.io/hanapbuhay-verification/',"
        fi
        ;;
    2)
        echo "🌐 Netlify Deployment (Drag & Drop):"
        echo "===================================="
        echo "1. Go to https://netlify.com"
        echo "2. Sign up/Login to your account"
        echo "3. Drag and drop email-verification.html onto the dashboard"
        echo "4. Wait for deployment to complete"
        echo "5. Copy the generated URL"
        echo ""
        echo "📝 Then update lib/services/auth_service.dart with your Netlify URL"
        ;;
    3)
        echo "⚡ Vercel Deployment:"
        echo "===================="
        echo "1. Go to https://vercel.com"
        echo "2. Sign up/Login to your account"
        echo "3. Click 'New Project'"
        echo "4. Upload email-verification.html"
        echo "5. Deploy"
        echo "6. Copy the generated URL"
        echo ""
        echo "📝 Then update lib/services/auth_service.dart with your Vercel URL"
        ;;
    4)
        echo "🔥 Firebase Hosting Deployment:"
        echo "==============================="
        echo "1. Install Firebase CLI: npm install -g firebase-tools"
        echo "2. Login: firebase login"
        echo "3. Initialize: firebase init hosting"
        echo "4. Select your project"
        echo "5. Set public directory to 'web'"
        echo "6. Deploy: firebase deploy"
        echo ""
        echo "📝 Copy the hosting URL and update lib/services/auth_service.dart"
        ;;
    5)
        echo "📁 Manual Deployment:"
        echo "====================="
        echo "1. Upload email-verification.html to any web hosting service"
        echo "2. Services like:"
        echo "   - 000webhost.com (free)"
        echo "   - infinityfree.net (free)"
        echo "   - your existing web host"
        echo "3. Get the URL where the file is hosted"
        echo ""
        echo "📝 Update lib/services/auth_service.dart with your hosting URL"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "⚙️  Next Steps:"
echo "==============="
echo "1. Deploy the email-verification.html file using your chosen method"
echo "2. Get the public URL of your deployed page"
echo "3. Update lib/services/auth_service.dart:"
echo "   - Replace 'https://your-domain.com/email-verification.html'"
echo "   - With your actual deployed URL"
echo "4. Update email-verification.html:"
echo "   - Replace 'YOUR_SUPABASE_URL' with your Supabase project URL"
echo "   - Replace 'YOUR_SUPABASE_ANON_KEY' with your Supabase anon key"
echo "5. Test the verification flow"

echo ""
echo "🧪 Testing:"
echo "==========="
echo "1. Register a test account"
echo "2. Click the verification link from email"
echo "3. Verify the web page works correctly"
echo "4. Test on different devices/browsers"

echo ""
echo "✅ Deployment script completed!"
echo "Check the web/README-email-verification.md for detailed documentation."
