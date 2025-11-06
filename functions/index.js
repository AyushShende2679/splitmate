const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const { getDynamicLinks } = require("firebase-admin/dynamic-links");

exports.createParentLink = functions.https.onCall(async (data, context) => {
  const code = data.code;

  // Your fallback long link
  const longLink = `https://splitmate.page.link/?link=splitmate://parent?code=${code}&apn=com.splitmate.app`;

  try {
    // Create a short Firebase Dynamic Link automatically
    const shortLink = await getDynamicLinks().createLink({
      dynamicLinkInfo: {
        domainUriPrefix: "https://splitmate.page.link", // ⚠️ use your real Dynamic Links domain from Firebase Console
        link: `splitmate://parent?code=${code}`,
        androidInfo: {
          androidPackageName: "com.splitmate.app", // ⚠️ use your actual app package ID
        },
      },
      suffix: { option: "SHORT" }
    });

    return { link: shortLink.shortLink };
  } catch (error) {
    console.error("❌ Error creating link:", error);
    return { error: error.message, link: longLink };
  }
});