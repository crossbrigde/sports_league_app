// 用戶管理模塊

// 獲取Firestore數據庫實例
const db = firebase.firestore();

// 載入用戶列表
function loadUsers() {
  const tableBody = document.getElementById('users-table-body');
  tableBody.innerHTML = '<tr><td colspan="6" class="text-center">載入中...</td></tr>';
  
  db.collection('users').get()
    .then(snapshot => {
      if (snapshot.empty) {
        tableBody.innerHTML = '<tr><td colspan="6" class="text-center">沒有找到用戶數據</td></tr>';
        return;
      }
      
      // 清空表格
      tableBody.innerHTML = '';
      
      // 填充用戶數據
      snapshot.forEach(doc => {
        const userData = doc.data();
        const userId = doc.id;
        
        const row = document.createElement('tr');
        row.innerHTML = `
          <td>${userId}</td>
          <td>${userData.nickname || '未設置'}</td>
          <td>${userData.email || '未設置'}</td>
          <td>
            <span class="badge ${getRoleBadgeClass(userData.role)}">
              ${getRoleDisplayName(userData.role)}
            </span>
          </td>
          <td>
            <span class="badge ${userData.status === 'active' ? 'bg-success' : 'bg-danger'}">
              ${userData.status === 'active' ? '啟用' : '停用'}
            </span>
          </td>
          <td>
            <button class="btn btn-sm btn-outline-primary edit-user-btn" data-user-id="${userId}">
              <i class="bi bi-pencil"></i>
            </button>
            <button class="btn btn-sm btn-outline-danger delete-user-btn" data-user-id="${userId}">
              <i class="bi bi-trash"></i>
            </button>
          </td>
        `;
        
        tableBody.appendChild(row);
      });
      
      // 添加編輯和刪除按鈕的事件監聽器
      addUserActionListeners();
    })
    .catch(error => {
      console.error('載入用戶數據時出錯:', error);
      tableBody.innerHTML = `<tr><td colspan="6" class="text-center text-danger">載入用戶數據時出錯: ${error.message}</td></tr>`;
    });
}

// 添加用戶操作按鈕的事件監聽器
function addUserActionListeners() {
  // 編輯按鈕
  document.querySelectorAll('.edit-user-btn').forEach(button => {
    button.addEventListener('click', function() {
      const userId = this.getAttribute('data-user-id');
      editUser(userId);
    });
  });
  
  // 刪除按鈕
  document.querySelectorAll('.delete-user-btn').forEach(button => {
    button.addEventListener('click', function() {
      const userId = this.getAttribute('data-user-id');
      deleteUser(userId);
    });
  });
}

// 編輯用戶
function editUser(userId) {
  db.collection('users').doc(userId).get()
    .then(doc => {
      if (doc.exists) {
        const userData = doc.data();
        window.showEditUserModal(userId, userData);
      } else {
        alert('找不到該用戶數據');
      }
    })
    .catch(error => {
      console.error('獲取用戶數據時出錯:', error);
      alert(`獲取用戶數據時出錯: ${error.message}`);
    });
}

// 刪除用戶
function deleteUser(userId) {
  if (confirm('確定要刪除此用戶嗎？此操作無法撤銷。')) {
    db.collection('users').doc(userId).delete()
      .then(() => {
        alert('用戶已成功刪除');
        loadUsers(); // 重新載入用戶列表
      })
      .catch(error => {
        console.error('刪除用戶時出錯:', error);
        alert(`刪除用戶時出錯: ${error.message}`);
      });
  }
}

// 創建新用戶
function createUser(userData) {
  // 檢查是否已存在相同電子郵件的用戶
  db.collection('users')
    .where('email', '==', userData.email)
    .get()
    .then(snapshot => {
      if (!snapshot.empty) {
        alert('已存在使用此電子郵件的用戶');
        return;
      }
      
      // 創建新用戶
      return db.collection('users').add({
        ...userData,
        createdAt: firebase.firestore.FieldValue.serverTimestamp()
      });
    })
    .then(docRef => {
      if (docRef) {
        alert('用戶創建成功');
        loadUsers(); // 重新載入用戶列表
      }
    })
    .catch(error => {
      console.error('創建用戶時出錯:', error);
      alert(`創建用戶時出錯: ${error.message}`);
    });
}

// 更新用戶
function updateUser(userId, userData) {
  db.collection('users').doc(userId).update({
    ...userData,
    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
  })
    .then(() => {
      alert('用戶資料已更新');
      loadUsers(); // 重新載入用戶列表
    })
    .catch(error => {
      console.error('更新用戶時出錯:', error);
      alert(`更新用戶時出錯: ${error.message}`);
    });
}

// 獲取角色顯示名稱
function getRoleDisplayName(role) {
  switch (role) {
    case 'admin': return '管理員';
    case 'referee': return '裁判';
    case 'viewer': return '觀眾';
    default: return '未知';
  }
}

// 獲取角色徽章樣式
function getRoleBadgeClass(role) {
  switch (role) {
    case 'admin': return 'bg-primary';
    case 'referee': return 'bg-success';
    case 'viewer': return 'bg-info';
    default: return 'bg-secondary';
  }
}

// 導出模塊
window.usersModule = {
  loadUsers,
  createUser,
  updateUser,
  deleteUser
};