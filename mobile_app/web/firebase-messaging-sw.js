// Arquivo: web/firebase-messaging-sw.js

importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBThCwjMIFFK3-6wUaIRvpR4-nh6O6aCtc",
  authDomain: "appdeliverymoto.firebaseapp.com",
  projectId: "appdeliverymoto",
  storageBucket: "appdeliverymoto.firebasestorage.app",
  messagingSenderId: "872160576746",
  appId: "1:872160576746:web:27217bf1018e3ebd5d4393"
});

const messaging = firebase.messaging();

// Opcional: Configura o que acontece quando recebe notificação em segundo plano
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Mensagem em segundo plano: ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // Ícone padrão do Flutter
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});