// 主要應用邏輯

// 當DOM加載完成後執行
document.addEventListener('DOMContentLoaded', function() {
  // 初始化認證狀態檢查
  window.authModule.checkAuthState();
  
  // 註冊事件監聽器
  registerEventListeners();
});

// 註冊所有事件監聽器
function registerEventListeners() {
  // 登入按鈕
  document.getElementById('login-btn').addEventListener('click', handleLogin);
  
  // Google登入按鈕
  document.getElementById('google-login-btn').addEventListener('click', handleGoogleLogin);
  
  // 登出按鈕
  document.getElementById('logout-btn').addEventListener('click', handleLogout);
  
  // 導航菜單項
  document.getElementById('dashboard-link').addEventListener('click', showDashboard);
  document.getElementById('users-link').addEventListener('click', showUsers);
  document.getElementById('roles-link').addEventListener('click', showRoles);
  document.getElementById('settings-link').addEventListener('click', showSettings);
  
  // 用戶管理按鈕
  document.getElementById('add-user-btn').addEventListener('click', showAddUserModal);
  document.getElementById('save-user-btn').addEventListener('click', saveUser);
}

// 處理電子郵件密碼登入
function handleLogin() {
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  
  if (!email || !password) {
    window.authModule.showError('請輸入電子郵件和密碼');
    return;
  }
  
  // 顯示載入狀態
  const loginBtn = document.getElementById('login-btn');
  const originalText = loginBtn.textContent;
  loginBtn.textContent = '登入中...';
  loginBtn.disabled = true;
  
  window.authModule.loginWithEmailPassword(email, password)
    .then(() => {
      // 登入成功，認證狀態變更會觸發 checkAuthState
    })
    .catch(error => {
      window.authModule.showError(error.message);
    })
    .finally(() => {
      // 恢復按鈕狀態
      loginBtn.textContent = originalText;
      loginBtn.disabled = false;
    });
}

// 處理Google登入
function handleGoogleLogin() {
  // 顯示載入狀態
  const googleBtn = document.getElementById('google-login-btn');
  const originalText = googleBtn.innerHTML;
  googleBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> 登入中...';
  googleBtn.disabled = true;
  
  window.authModule.loginWithGoogle()
    .then(() => {
      // 登入成功，認證狀態變更會觸發 checkAuthState
    })
    .catch(error => {
      window.authModule.showError(error.message);
    })
    .finally(() => {
      // 恢復按鈕狀態
      googleBtn.innerHTML = originalText;
      googleBtn.disabled = false;
    });
}

// 處理登出
function handleLogout() {
  window.authModule.logout();
}

// 顯示儀表板
function showDashboard() {
  setActiveNavItem('dashboard-link');
  document.getElementById('dashboard-container').classList.remove('d-none');
  document.getElementById('users-container').classList.add('d-none');
  document.getElementById('roles-container').classList.add('d-none');
  
  // 載入儀表板數據
  window.dashboardModule.loadDashboardData();
}

// 顯示用戶管理
function showUsers() {
  setActiveNavItem('users-link');
  document.getElementById('dashboard-container').classList.add('d-none');
  document.getElementById('users-container').classList.remove('d-none');
  document.getElementById('roles-container').classList.add('d-none');
  
  // 載入用戶數據
  window.usersModule.loadUsers();
}

// 顯示角色管理
function showRoles() {
  setActiveNavItem('roles-link');
  document.getElementById('dashboard-container').classList.add('d-none');
  document.getElementById('users-container').classList.add('d-none');
  document.getElementById('roles-container').classList.remove('d-none');
}

// 顯示系統設置
function showSettings() {
  setActiveNavItem('settings-link');
  // 暫未實現設置頁面
}

// 設置當前活動的導航項
function setActiveNavItem(itemId) {
  // 移除所有導航項的活動狀態
  document.querySelectorAll('#sidebar .nav-link').forEach(item => {
    item.classList.remove('active');
  });
  
  // 設置當前項為活動狀態
  document.getElementById(itemId).classList.add('active');
}

// 顯示添加用戶模態框
function showAddUserModal() {
  // 重置表單
  document.getElementById('user-form').reset();
  document.getElementById('user-id').value = '';
  document.getElementById('user-modal-title').textContent = '新增用戶';
  
  // 顯示模態框
  const userModal = new bootstrap.Modal(document.getElementById('user-modal'));
  userModal.show();
}

// 顯示編輯用戶模態框
function showEditUserModal(userId, userData) {
  // 填充表單數據
  document.getElementById('user-id').value = userId;
  document.getElementById('user-email').value = userData.email || '';
  document.getElementById('user-nickname').value = userData.nickname || '';
  document.getElementById('user-role').value = userData.role || 'viewer';
  document.getElementById('user-status').value = userData.status || 'active';
  
  document.getElementById('user-modal-title').textContent = '編輯用戶';
  
  // 顯示模態框
  const userModal = new bootstrap.Modal(document.getElementById('user-modal'));
  userModal.show();
}

// 保存用戶數據
function saveUser() {
  const userId = document.getElementById('user-id').value;
  const userData = {
    email: document.getElementById('user-email').value,
    nickname: document.getElementById('user-nickname').value,
    role: document.getElementById('user-role').value,
    status: document.getElementById('user-status').value
  };
  
  if (userId) {
    // 更新現有用戶
    window.usersModule.updateUser(userId, userData);
  } else {
    // 創建新用戶
    window.usersModule.createUser(userData);
  }
  
  // 關閉模態框
  const userModal = bootstrap.Modal.getInstance(document.getElementById('user-modal'));
  userModal.hide();
}

// 導出全局函數
window.showDashboard = showDashboard;
window.showUsers = showUsers;
window.showRoles = showRoles;
window.showEditUserModal = showEditUserModal;