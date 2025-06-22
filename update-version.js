// 更新Firebase數據庫中的版本號
const { initializeApp } = require('firebase/app');
const { getDatabase, ref, set } = require('firebase/database');

const firebaseConfig = {
  projectId: 'sports-league-app-d25e2',
  databaseURL: 'https://sports-league-app-d25e2-default-rtdb.asia-southeast1.firebasedatabase.app',
  apiKey: 'AIzaSyDlphPjw9Ivsl6Uo9h33Y10T-2LwoIRxpQ',
  authDomain: 'sports-league-app-d25e2.firebaseapp.com',
  storageBucket: 'sports-league-app-d25e2.appspot.com',
  messagingSenderId: '757686243952',
  appId: '1:757686243952:web:fe291194a5e7b463a3dab5'
};

// 初始化Firebase
const app = initializeApp(firebaseConfig);
const database = getDatabase(app);

// 更新版本號
const versionRef = ref(database, 'version');
set(versionRef, '1.8.0')  // 從1.4.3更新為1.8.0
  .then(() => {
    console.log('版本已成功更新為1.8.0');
    process.exit(0);
  })
  .catch((error) => {
    console.error('更新版本失敗:', error);
    process.exit(1);
  });