// 認證相關功能

// 獲取Firebase Auth實例
const auth = firebase.auth();

// 設置身份驗證持久性為LOCAL，確保用戶登入狀態在頁面重新載入後仍然保持
auth.setPersistence(firebase.auth.Auth.Persistence.LOCAL).catch(error => {
  console.error('設置身份驗證持久性時出錯:', error);
});

// 創建Google登入提供者
const googleProvider = new firebase.auth.GoogleAuthProvider();

// 檢查用戶是否已登入
function checkAuthState() {
  // 先檢查是否有重定向登入結果
  // 這必須在auth.onAuthStateChanged之前調用，以確保正確處理重定向結果
  checkRedirectResult();
  
  // 檢查本地存儲中是否有用戶登入狀態
  const savedUser = localStorage.getItem('currentUser');
  if (savedUser) {
    try {
      const userData = JSON.parse(savedUser);
      console.log('從本地存儲恢復用戶狀態:', userData);
    } catch (e) {
      console.error('解析本地存儲的用戶數據時出錯:', e);
      localStorage.removeItem('currentUser');
    }
  }
  
  // 然後監聽認證狀態變化
  auth.onAuthStateChanged(user => {
    console.log('認證狀態變更:', user ? '已登入' : '未登入');
    if (user) {
      // 用戶已登入，保存到本地存儲
      localStorage.setItem('currentUser', JSON.stringify({
        uid: user.uid,
        email: user.email,
        displayName: user.displayName
      }));
      // 檢查是否為管理員
      checkAdminRole(user.uid);
    } else {
      // 用戶未登入，清除本地存儲並顯示登入頁面
      localStorage.removeItem('currentUser');
      showLoginForm();
    }
  });
}

// 檢查用戶是否具有管理員角色
function checkAdminRole(uid) {
  const db = firebase.firestore();
  db.collection('users').doc(uid).get()
    .then(doc => {
      if (doc.exists && doc.data().role === 'admin') {
        // 用戶是管理員，顯示管理界面
        hideLoginForm();
        showDashboard();
        updateUIWithUserInfo(doc.data());
      } else if (!doc.exists) {
        // 用戶在Firestore中不存在，但已通過Firebase Authentication驗證
        // 顯示設置管理員的選項
        showLoginForm();
        // 顯示提示訊息
        const infoElement = document.createElement('div');
        infoElement.className = 'alert alert-info mt-3';
        infoElement.textContent = '您已成功登入，但尚未設置管理員權限。請點擊「設置為管理員」按鈕。';
        document.getElementById('login-error').before(infoElement);
      } else {
        // 用戶不是管理員，顯示錯誤訊息
        auth.signOut().then(() => {
          showLoginForm();
          showError('您沒有管理員權限');
        });
      }
    })
    .catch(error => {
      console.error('檢查管理員角色時出錯:', error);
      showError('驗證權限時發生錯誤');
    });
}

// 使用電子郵件密碼登入功能
function loginWithEmailPassword(email, password) {
  return auth.signInWithEmailAndPassword(email, password)
    .catch(error => {
      console.error('登入錯誤:', error);
      let errorMessage = '登入失敗，請檢查您的電子郵件和密碼';
      
      // 處理常見的Firebase錯誤
      if (error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password') {
        errorMessage = '電子郵件或密碼不正確';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = '電子郵件格式不正確';
      } else if (error.code === 'auth/user-disabled') {
        errorMessage = '此帳號已被停用';
      } else if (error.code === 'auth/too-many-requests') {
        errorMessage = '登入嘗試次數過多，請稍後再試';
      }
      
      throw new Error(errorMessage);
    });
}

// 使用Google登入功能
function loginWithGoogle() {
  // 檢查當前環境
  const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
  
  // 在重開機後，可能需要重新初始化Google提供者
  googleProvider.addScope('profile');
  googleProvider.addScope('email');
  
  // 設置自定義參數以改善重定向體驗
  googleProvider.setCustomParameters({
    // 強制重新選擇帳號
    prompt: 'select_account',
    // 設置重定向URI，確保與Firebase控制台中的設置匹配
    redirect_uri: window.location.origin + window.location.pathname
  });
  
  // 在本地開發環境中使用重定向方式登入，在生產環境使用彈窗方式
  if (isLocalhost) {
    // 使用重定向方式登入
    console.log('使用重定向方式登入，重定向URI:', window.location.origin + window.location.pathname);
    auth.signInWithRedirect(googleProvider).catch(handleGoogleLoginError);
    return Promise.resolve(); // 返回一個已解決的Promise，因為實際登入結果將在頁面重定向後處理
  } else {
    // 在生產環境使用彈窗方式
    return auth.signInWithPopup(googleProvider).catch(handleGoogleLoginError);
  }
}

// 處理Google登入錯誤
function handleGoogleLoginError(error) {
  console.error('Google登入錯誤:', error);
  let errorMessage = 'Google登入失敗';
  
  // 處理常見的Firebase錯誤
  if (error.code === 'auth/account-exists-with-different-credential') {
    errorMessage = '此電子郵件已經與其他登入方式關聯';
  } else if (error.code === 'auth/popup-blocked') {
    errorMessage = '登入彈窗被阻擋，請允許彈窗';
  } else if (error.code === 'auth/popup-closed-by-user') {
    errorMessage = '登入彈窗被關閉，請重試';
  } else if (error.code === 'auth/cancelled-popup-request') {
    errorMessage = '登入請求已取消，請重試';
  } else if (error.code === 'auth/unauthorized-domain') {
    // 提供更詳細的錯誤訊息和解決方案
    const currentDomain = window.location.hostname;
    errorMessage = `當前域名 "${currentDomain}" 未被授權進行Google登入。重開機後可能需要重新授權域名。請在Firebase控制台 > Authentication > Sign-in method > Google > 授權域名中添加此域名。`;
    console.warn('未授權域名錯誤，請確認Firebase控制台中的授權域名設置是否包含:', currentDomain);
  }
  
  throw new Error(errorMessage);
}

// 檢查是否有重定向結果
function checkRedirectResult() {
  auth.getRedirectResult().then(result => {
    if (result.user) {
      // 用戶已成功通過重定向登入
      console.log('重定向登入成功:', result.user);
      // 確保UI更新以反映登入狀態
      hideLoginForm();
      // 使用全局的showDashboard函數
      window.showDashboard();
      // 檢查管理員角色
      checkAdminRole(result.user.uid);
    }
  }).catch(error => {
    console.error('重定向登入錯誤:', error);
    showError('Google登入失敗: ' + error.message);
  });
}


// 登出功能
function logout() {
  return auth.signOut()
    .then(() => {
      // 清除本地存儲的用戶狀態
      localStorage.removeItem('currentUser');
      showLoginForm();
      console.log('用戶已成功登出，並清除本地存儲');
    })
    .catch(error => {
      console.error('登出錯誤:', error);
    });
}

// 顯示登入表單
function showLoginForm() {
  document.getElementById('login-container').classList.remove('d-none');
  document.getElementById('dashboard-container').classList.add('d-none');
  document.getElementById('users-container').classList.add('d-none');
  document.getElementById('roles-container').classList.add('d-none');
  document.getElementById('sidebar').classList.add('d-none');
}

// 隱藏登入表單
function hideLoginForm() {
  document.getElementById('login-container').classList.add('d-none');
  document.getElementById('sidebar').classList.remove('d-none');
}



// 顯示錯誤訊息
function showError(message) {
  const errorElement = document.getElementById('login-error');
  errorElement.textContent = message;
  errorElement.classList.remove('d-none');
}

// 更新UI顯示用戶信息
function updateUIWithUserInfo(userData) {
  // 這裡可以添加顯示當前登入用戶信息的代碼
  console.log('當前登入用戶:', userData);
}

// 導出函數供其他模塊使用
window.authModule = {
  checkAuthState,
  loginWithEmailPassword,
  loginWithGoogle,
  logout,
  showLoginForm,
  hideLoginForm,
  showError,
  checkRedirectResult
};