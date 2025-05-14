// 管理員設置腳本

// 此腳本用於將現有的Firebase Authentication帳號設置為管理員

// 獲取Firebase Auth和Firestore實例
const auth = firebase.auth();
const db = firebase.firestore();

// 設置管理員帳號
function setupAdminAccount() {
  // 檢查用戶是否已登入
  const user = auth.currentUser;
  
  if (!user) {
    alert('請先使用您的Firebase帳號登入');
    return;
  }
  
  // 檢查用戶是否已經是管理員
  db.collection('users').doc(user.uid).get()
    .then(doc => {
      if (doc.exists && doc.data().role === 'admin') {
        alert('您的帳號已經是管理員');
        return;
      }
      
      // 將用戶設置為管理員
      return db.collection('users').doc(user.uid).set({
        email: user.email,
        nickname: user.displayName || '管理員',
        role: 'admin',
        status: 'active',
        createdAt: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    })
    .then(() => {
      alert('管理員帳號設置成功！請重新登入系統。');
      // 重新載入頁面以應用變更
      setTimeout(() => {
        window.location.reload();
      }, 1500);
    })
    .catch(error => {
      console.error('設置管理員帳號時出錯:', error);
      alert(`設置管理員帳號時出錯: ${error.message}`);
    });
}

// 添加設置管理員按鈕
function addSetupAdminButton() {
  const loginContainer = document.getElementById('login-container');
  const cardBody = loginContainer.querySelector('.card-body');
  
  // 創建設置管理員按鈕
  const setupButton = document.createElement('button');
  setupButton.id = 'setup-admin-btn';
  setupButton.className = 'btn btn-secondary mt-2';
  setupButton.textContent = '設置為管理員';
  setupButton.onclick = setupAdminAccount;
  
  // 添加說明文字
  const helpText = document.createElement('p');
  helpText.className = 'text-muted mt-3 small';
  helpText.textContent = '如果這是您第一次使用管理系統，請先使用您原有的Firebase Authentication帳號登入，然後點擊「設置為管理員」按鈕將您的帳號設置為管理員。';
  
  // 添加額外說明
  const extraHelp = document.createElement('p');
  extraHelp.className = 'text-muted small';
  extraHelp.textContent = '注意：您只需要使用原有的帳號密碼登入，無需創建新帳號。';
  
  // 將按鈕和說明添加到登入表單下方
  const buttonContainer = document.createElement('div');
  buttonContainer.className = 'd-grid gap-2 mt-3';
  buttonContainer.appendChild(setupButton);
  
  cardBody.appendChild(buttonContainer);
  cardBody.appendChild(helpText);
  cardBody.appendChild(extraHelp);
}

// 當頁面加載完成後執行
document.addEventListener('DOMContentLoaded', function() {
  // 添加設置管理員按鈕
  addSetupAdminButton();
});