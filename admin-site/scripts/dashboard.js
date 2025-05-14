// 儀表板模塊

// 獲取Firestore數據庫實例
const db = firebase.firestore();

// 載入儀表板數據
function loadDashboardData() {
  // 顯示載入中狀態
  document.getElementById('total-users').textContent = '載入中...';
  document.getElementById('admin-count').textContent = '載入中...';
  document.getElementById('referee-count').textContent = '載入中...';
  
  // 獲取用戶總數
  db.collection('users').get()
    .then(snapshot => {
      const totalUsers = snapshot.size;
      document.getElementById('total-users').textContent = totalUsers;
      
      // 計算不同角色的用戶數量
      let adminCount = 0;
      let refereeCount = 0;
      
      snapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.role === 'admin') {
          adminCount++;
        } else if (userData.role === 'referee') {
          refereeCount++;
        }
      });
      
      document.getElementById('admin-count').textContent = adminCount;
      document.getElementById('referee-count').textContent = refereeCount;
    })
    .catch(error => {
      console.error('載入儀表板數據時出錯:', error);
      document.getElementById('total-users').textContent = '錯誤';
      document.getElementById('admin-count').textContent = '錯誤';
      document.getElementById('referee-count').textContent = '錯誤';
    });
  
  // 這裡可以添加更多儀表板數據的載入邏輯
  // 例如最近的活動、系統狀態等
}

// 導出模塊
window.dashboardModule = {
  loadDashboardData
};