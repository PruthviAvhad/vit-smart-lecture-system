const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationTrigger = functions.firestore
    .document('notification_triggers/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();

        const message = {
            notification: {
                title: data.title,
                body: data.body,
            },
            topic: data.topic, // Handled dynamically (TY_Div_A, faculty, or all_campus)
        };

        try {
            await admin.messaging().send(message);
            return snap.ref.update({ status: 'sent', sentAt: admin.firestore.FieldValue.serverTimestamp() });
        } catch (error) {
            console.error("FCM Error:", error);
            return snap.ref.update({ status: 'failed', error: error.message });
        }
    });