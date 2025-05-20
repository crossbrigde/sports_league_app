// 數據管理頁面的功能

// 初始化數據管理頁面
function initDataManagement() {
  // 獲取比賽數據
  fetchMatches();
  // 獲取賽程數據
  fetchSchedules();
  
  // 綁定按鈕事件
  document.getElementById('add-match-btn').addEventListener('click', showAddMatchModal);
  document.getElementById('add-schedule-btn').addEventListener('click', showAddScheduleModal);
  document.getElementById('save-match-btn').addEventListener('click', saveMatch);
  document.getElementById('save-schedule-btn').addEventListener('click', saveSchedule);
}

// 獲取比賽數據
function fetchMatches() {
  const db = firebase.firestore();
  const matchesTableBody = document.getElementById('matches-table-body');
  matchesTableBody.innerHTML = '';
  
  // 創建一個Map來存儲每個賽程及其相關的比賽
  const schedulesMap = new Map();
  
  // 首先獲取所有賽程數據
  db.collection('schedules').get().then((schedulesSnapshot) => {
    if (schedulesSnapshot.empty) {
      matchesTableBody.innerHTML = '<tr><td colspan="6" class="text-center">暫無賽程數據</td></tr>';
      return;
    }
    
    // 處理所有賽程數據
    schedulesSnapshot.forEach((doc) => {
      const schedule = doc.data();
      schedule.id = doc.id; // 保存賽程ID
      schedulesMap.set(doc.id, {
        schedule: schedule,
        matches: [] // 初始化一個空數組來存儲相關的比賽
      });
    });
    
    // 然後獲取所有比賽數據
    db.collection('matches').get().then((matchesSnapshot) => {
      if (matchesSnapshot.empty) {
        matchesTableBody.innerHTML = '<tr><td colspan="6" class="text-center">暫無比賽數據</td></tr>';
        return;
      }
      
      // 處理比賽數據，將每個比賽添加到對應的賽程中
      matchesSnapshot.forEach((matchDoc) => {
        const match = matchDoc.data();
        match.id = matchDoc.id; // 保存比賽ID
        
        // 檢查比賽是否有tournamentId字段，並且該ID是否在我們的賽程Map中
        if (match.tournamentId && schedulesMap.has(match.tournamentId)) {
          schedulesMap.get(match.tournamentId).matches.push(match);
        }
      });
      
      // 創建比賽列表標題
      const titleRow = document.createElement('tr');
      titleRow.className = 'table-primary';
      titleRow.innerHTML = `
        <th colspan="6" class="text-center fs-5">比賽列表</th>
      `;
      matchesTableBody.appendChild(titleRow);
      
      // 現在渲染賽程和相關的比賽
      schedulesMap.forEach((data, scheduleId) => {
        const schedule = data.schedule;
        const matches = data.matches;
        
        // 創建賽程標題行
        const tournamentRow = document.createElement('tr');
        tournamentRow.className = 'table-secondary';
        tournamentRow.innerHTML = `
          <th colspan="6" class="ps-3">賽程名稱：${schedule.matchName || '-'}</th>
        `;
        matchesTableBody.appendChild(tournamentRow);
        
        // 創建表頭行
        const headerRow = document.createElement('tr');
        headerRow.className = 'table-light';
        headerRow.innerHTML = `
          <th>場次</th>
          <th>藍方選手</th>
          <th>紅方選手</th>
          <th>狀態</th>
          <th>操作</th>
          <th></th>
        `;
        matchesTableBody.appendChild(headerRow);
        
        // 如果有相關比賽，則顯示它們
        if (matches.length > 0) {
          matches.forEach(match => {
            const matchRow = document.createElement('tr');
            matchRow.innerHTML = `
              <td>${schedule.round || '-'}</td>
              <td>${match.bluePlayer || '-'}</td>
              <td>${match.redPlayer || '-'}</td>
              <td>
                <span class="badge ${match.status === 'ongoing' ? 'bg-success' : 'bg-secondary'}">
                  ${match.status === 'ongoing' ? '進行中' : '已結束'}
                </span>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editMatch('${match.id}')">編輯</button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteMatch('${match.id}')">刪除</button>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-info" onclick="editMatchScores('${match.id}')">編輯得分</button>
              </td>
            `;
            matchesTableBody.appendChild(matchRow);
          });
        } else {
          // 如果沒有相關比賽，顯示提示信息
          const noMatchRow = document.createElement('tr');
          noMatchRow.innerHTML = `<td colspan="6" class="text-center">此賽程下暫無比賽數據</td>`;
          matchesTableBody.appendChild(noMatchRow);
        }
        
        // 添加一個空行作為分隔
        const spacerRow = document.createElement('tr');
        spacerRow.innerHTML = `<td colspan="6" class="p-2"></td>`;
        matchesTableBody.appendChild(spacerRow);
      });
      
    }).catch((error) => {
      console.error('獲取比賽數據失敗:', error);
      alert('獲取比賽數據失敗，請稍後再試');
    });
  }).catch((error) => {
    console.error('獲取賽程數據失敗:', error);
    alert('獲取賽程數據失敗，請稍後再試');
  });
}

// 獲取賽程數據
function fetchSchedules() {
  const db = firebase.firestore();
  db.collection('schedules').get().then((snapshot) => {
    const schedulesTableBody = document.getElementById('schedules-table-body');
    schedulesTableBody.innerHTML = '';
    
    if (snapshot.empty) {
      schedulesTableBody.innerHTML = '<tr><td colspan="6" class="text-center">暫無賽程數據</td></tr>';
      return;
    }
    
    // 創建一個Map來存儲每個賽程及其相關的比賽
    const schedulesMap = new Map();
    
    // 首先處理所有賽程數據
    snapshot.forEach((doc) => {
      const schedule = doc.data();
      schedule.id = doc.id; // 保存賽程ID
      schedulesMap.set(doc.id, {
        schedule: schedule,
        matches: [] // 初始化一個空數組來存儲相關的比賽
      });
    });
    
    // 然後獲取所有比賽數據
    db.collection('matches').get().then((matchesSnapshot) => {
      // 處理比賽數據，將每個比賽添加到對應的賽程中
      matchesSnapshot.forEach((matchDoc) => {
        const match = matchDoc.data();
        match.id = matchDoc.id; // 保存比賽ID
        
        // 檢查比賽是否有tournamentId字段，並且該ID是否在我們的賽程Map中
        if (match.tournamentId && schedulesMap.has(match.tournamentId)) {
          schedulesMap.get(match.tournamentId).matches.push(match);
        }
      });
      
      // 創建比賽列表標題
      const titleRow = document.createElement('tr');
      titleRow.className = 'table-primary';
      titleRow.innerHTML = `
        <th colspan="6" class="text-center fs-5">比賽列表</th>
      `;
      schedulesTableBody.appendChild(titleRow);
      
      // 現在渲染賽程和相關的比賽
      schedulesMap.forEach((data, scheduleId) => {
        const schedule = data.schedule;
        const matches = data.matches;
        
        // 創建賽程標題行
        const tournamentRow = document.createElement('tr');
        tournamentRow.className = 'table-secondary';
        tournamentRow.innerHTML = `
          <th colspan="6" class="ps-3">賽程名稱：${schedule.matchName || '-'}</th>
        `;
        schedulesTableBody.appendChild(tournamentRow);
        
        // 創建表頭行
        const headerRow = document.createElement('tr');
        headerRow.className = 'table-light';
        headerRow.innerHTML = `
          <th>場次</th>
          <th>藍方選手</th>
          <th>紅方選手</th>
          <th>狀態</th>
          <th>操作</th>
          <th></th>
        `;
        schedulesTableBody.appendChild(headerRow);
        
        // 如果有相關比賽，則顯示它們
        if (matches.length > 0) {
          matches.forEach(match => {
            const matchRow = document.createElement('tr');
            matchRow.innerHTML = `
              <td>${schedule.round || '-'}</td>
              <td>${match.bluePlayer || '-'}</td>
              <td>${match.redPlayer || '-'}</td>
              <td>
                <span class="badge ${match.status === 'ongoing' ? 'bg-success' : 'bg-secondary'}">
                  ${match.status === 'ongoing' ? '進行中' : '已結束'}
                </span>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editMatch('${match.id}')">編輯</button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteMatch('${match.id}')">刪除</button>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-info" onclick="editMatchScores('${match.id}')">編輯得分</button>
              </td>
            `;
            schedulesTableBody.appendChild(matchRow);
          });
        } else {
          // 如果沒有相關比賽，顯示提示信息
          const noMatchRow = document.createElement('tr');
          noMatchRow.innerHTML = `<td colspan="6" class="text-center">此賽程下暫無比賽數據</td>`;
          schedulesTableBody.appendChild(noMatchRow);
        }
        
        // 添加一個空行作為分隔
        const spacerRow = document.createElement('tr');
        spacerRow.innerHTML = `<td colspan="6" class="p-2"></td>`;
        schedulesTableBody.appendChild(spacerRow);
      });
      
    }).catch((error) => {
      console.error('獲取比賽數據失敗:', error);
      alert('獲取比賽數據失敗，請稍後再試');
    });
  }).catch((error) => {
    console.error('獲取賽程數據失敗:', error);
    alert('獲取賽程數據失敗，請稍後再試');
  });
}

// 獲取賽程狀態對應的樣式
function getScheduleStatusBadge(status) {
  switch(status) {
    case 'upcoming': return 'bg-warning';
    case 'ongoing': return 'bg-success';
    case 'completed': return 'bg-secondary';
    default: return 'bg-info';
  }
}

// 獲取賽程狀態對應的文字
function getScheduleStatusText(status) {
  switch(status) {
    case 'upcoming': return '即將開始';
    case 'ongoing': return '進行中';
    case 'completed': return '已完成';
    default: return '未知';
  }
}

// 顯示新增比賽模態框
function showAddMatchModal() {
  // 重置表單
  document.getElementById('match-form').reset();
  document.getElementById('match-id').value = '';
  document.getElementById('match-modal-title').textContent = '新增比賽';
  
  // 載入賽程選項
  loadTournamentOptions();
  
  // 顯示模態框
  const matchModal = new bootstrap.Modal(document.getElementById('match-modal'));
  matchModal.show();
}

// 載入賽程選項到比賽模態框
function loadTournamentOptions() {
  const db = firebase.firestore();
  const tournamentSelect = document.getElementById('match-tournament');
  
  // 清空現有選項，只保留第一個「請選擇賽程」選項
  tournamentSelect.innerHTML = '<option value="" selected>請選擇賽程（可選）</option>';
  
  db.collection('schedules').get().then((snapshot) => {
    snapshot.forEach((doc) => {
      const schedule = doc.data();
      const option = document.createElement('option');
      option.value = doc.id;
      option.textContent = schedule.matchName + ' - ' + schedule.round;
      tournamentSelect.appendChild(option);
    });
  }).catch((error) => {
    console.error('獲取賽程數據失敗:', error);
  });
}

// 顯示新增賽程模態框
function showAddScheduleModal() {
  // 重置表單
  document.getElementById('schedule-form').reset();
  document.getElementById('schedule-id').value = '';
  document.getElementById('schedule-modal-title').textContent = '新增賽程';
  
  // 載入比賽選項
  loadMatchOptions();
  
  // 顯示模態框
  const scheduleModal = new bootstrap.Modal(document.getElementById('schedule-modal'));
  scheduleModal.show();
}

// 載入比賽選項到賽程模態框
function loadMatchOptions() {
  const db = firebase.firestore();
  const matchSelect = document.getElementById('schedule-match');
  
  // 清空現有選項
  matchSelect.innerHTML = '<option value="" disabled selected>請選擇比賽</option>';
  
  db.collection('matches').get().then((snapshot) => {
    snapshot.forEach((doc) => {
      const match = doc.data();
      const option = document.createElement('option');
      option.value = doc.id;
      option.textContent = match.name;
      matchSelect.appendChild(option);
    });
  }).catch((error) => {
    console.error('獲取比賽數據失敗:', error);
  });
}

// 編輯比賽
function editMatch(matchId) {
  // 先載入賽程選項
  loadTournamentOptions();
  
  const db = firebase.firestore();
  db.collection('matches').doc(matchId).get().then((doc) => {
    if (doc.exists) {
      const match = doc.data();
      
      // 填充表單數據
      document.getElementById('match-id').value = matchId;
      document.getElementById('match-name').value = match.name || '';
      document.getElementById('match-type').value = match.type || 'tournament';
      document.getElementById('match-status').value = match.status || 'upcoming';
      document.getElementById('match-description').value = match.description || '';
      
      // 處理日期格式
      if (match.startDate) {
        const date = new Date(match.startDate);
        const formattedDate = date.toISOString().split('T')[0];
        document.getElementById('match-start-date').value = formattedDate;
      }
      
      // 設置所屬賽程（可能需要等待賽程選項載入完成）
      setTimeout(() => {
        if (match.tournamentId) {
          document.getElementById('match-tournament').value = match.tournamentId;
        }
      }, 500);
      
      document.getElementById('match-modal-title').textContent = '編輯比賽';
      
      // 顯示模態框
      const matchModal = new bootstrap.Modal(document.getElementById('match-modal'));
      matchModal.show();
    } else {
      alert('找不到該比賽數據');
    }
  }).catch((error) => {
    console.error('獲取比賽數據失敗:', error);
    alert('獲取比賽數據失敗，請稍後再試');
  });
}

// 編輯比賽得分
function editMatchScores(matchId) {
  const db = firebase.firestore();
  db.collection('matches').doc(matchId).get().then((doc) => {
    if (doc.exists) {
      const match = doc.data();
      
      // 填充比賽基本信息
      document.getElementById('score-match-id').value = matchId;
      document.getElementById('score-match-name').textContent = match.name || '未命名比賽';
      document.getElementById('score-blue-player').textContent = match.bluePlayer || '藍方選手';
      document.getElementById('score-red-player').textContent = match.redPlayer || '紅方選手';
      
      // 清空得分表格
      const scoreTableBody = document.getElementById('score-table-body');
      scoreTableBody.innerHTML = '';
      
      // 獲取比賽得分記錄
      db.collection('matches').doc(matchId).collection('scores').orderBy('timestamp').get().then((scoresSnapshot) => {
        if (scoresSnapshot.empty) {
          // 如果沒有得分記錄，顯示空行
          const emptyRow = document.createElement('tr');
          emptyRow.innerHTML = `<td colspan="4" class="text-center">暫無得分記錄</td>`;
          scoreTableBody.appendChild(emptyRow);
        } else {
          // 顯示所有得分記錄
          scoresSnapshot.forEach((scoreDoc, index) => {
            const score = scoreDoc.data();
            const scoreRow = document.createElement('tr');
            scoreRow.innerHTML = `
              <td>${index + 1}</td>
              <td>
                <select class="form-select form-select-sm score-player" data-score-id="${scoreDoc.id}">
                  <option value="blue" ${score.player === 'blue' ? 'selected' : ''}>藍方</option>
                  <option value="red" ${score.player === 'red' ? 'selected' : ''}>紅方</option>
                </select>
              </td>
              <td>
                <input type="number" class="form-control form-control-sm score-points" data-score-id="${scoreDoc.id}" value="${score.points || 1}" min="1" max="5">
              </td>
              <td>
                <button class="btn btn-sm btn-danger delete-score" data-score-id="${scoreDoc.id}">刪除</button>
              </td>
            `;
            scoreTableBody.appendChild(scoreRow);
          });
          
          // 添加得分記錄的事件監聽器
          addScoreEventListeners(matchId);
        }
        
        // 顯示模態框
        const scoreModal = new bootstrap.Modal(document.getElementById('score-modal'));
        scoreModal.show();
        
      }).catch((error) => {
        console.error('獲取得分記錄失敗:', error);
        alert('獲取得分記錄失敗，請稍後再試');
      });
      
    } else {
      alert('找不到該比賽數據');
    }
  }).catch((error) => {
    console.error('獲取比賽數據失敗:', error);
    alert('獲取比賽數據失敗，請稍後再試');
  });
}

// 添加得分記錄的事件監聽器
function addScoreEventListeners(matchId) {
  // 監聽得分選手變更
  document.querySelectorAll('.score-player').forEach(select => {
    select.addEventListener('change', function() {
      updateScore(matchId, this.getAttribute('data-score-id'), {
        player: this.value
      });
    });
  });
  
  // 監聽得分點數變更
  document.querySelectorAll('.score-points').forEach(input => {
    input.addEventListener('change', function() {
      updateScore(matchId, this.getAttribute('data-score-id'), {
        points: parseInt(this.value) || 1
      });
    });
  });
  
  // 監聽刪除得分按鈕
  document.querySelectorAll('.delete-score').forEach(button => {
    button.addEventListener('click', function() {
      if (confirm('確定要刪除此得分記錄嗎？')) {
        deleteScore(matchId, this.getAttribute('data-score-id'));
      }
    });
  });
}

// 更新得分記錄
function updateScore(matchId, scoreId, data) {
  const db = firebase.firestore();
  const user = firebase.auth().currentUser;
  
  // 添加修改者信息
  data.updatedAt = new Date().toISOString();
  data.updatedBy = user ? user.uid : 'unknown';
  
  db.collection('matches').doc(matchId).collection('scores').doc(scoreId).update(data)
    .then(() => {
      console.log('得分記錄已更新');
    })
    .catch((error) => {
      console.error('更新得分記錄失敗:', error);
      alert('更新得分記錄失敗，請稍後再試');
    });
}

// 刪除得分記錄
function deleteScore(matchId, scoreId) {
  const db = firebase.firestore();
  db.collection('matches').doc(matchId).collection('scores').doc(scoreId).delete()
    .then(() => {
      // 重新載入得分記錄
      editMatchScores(matchId);
    })
    .catch((error) => {
      console.error('刪除得分記錄失敗:', error);
      alert('刪除得分記錄失敗，請稍後再試');
    });
}

// 添加新得分記錄
function addNewScore() {
  const matchId = document.getElementById('score-match-id').value;
  const player = document.getElementById('new-score-player').value;
  const points = parseInt(document.getElementById('new-score-points').value) || 1;
  
  if (!matchId) {
    alert('比賽ID不能為空');
    return;
  }
  
  const db = firebase.firestore();
  const user = firebase.auth().currentUser;
  
  const scoreData = {
    player: player,
    points: points,
    timestamp: new Date().toISOString(),
    createdAt: new Date().toISOString(),
    createdBy: user ? user.uid : 'unknown'
  };
  
  db.collection('matches').doc(matchId).collection('scores').add(scoreData)
    .then(() => {
      // 重置輸入框
      document.getElementById('new-score-points').value = '1';
      
      // 重新載入得分記錄
      editMatchScores(matchId);
    })
    .catch((error) => {
      console.error('添加得分記錄失敗:', error);
      alert('添加得分記錄失敗，請稍後再試');
    });
}

// 刪除比賽
function deleteMatch(matchId) {
  if (confirm('確定要刪除此比賽嗎？此操作不可撤銷。')) {
    const db = firebase.firestore();
    db.collection('matches').doc(matchId).delete().then(() => {
      alert('比賽已成功刪除');
      fetchMatches();
    }).catch((error) => {
      console.error('刪除比賽失敗:', error);
      alert('刪除比賽失敗，請稍後再試');
    });
  }
}

// 編輯賽程
function editSchedule(scheduleId) {
  // 載入比賽選項
  loadMatchOptions();
  
  const db = firebase.firestore();
  db.collection('schedules').doc(scheduleId).get().then((doc) => {
    if (doc.exists) {
      const schedule = doc.data();
      
      // 填充表單數據
      document.getElementById('schedule-id').value = scheduleId;
      document.getElementById('schedule-round').value = schedule.round || '';
      document.getElementById('schedule-location').value = schedule.location || '';
      document.getElementById('schedule-status').value = schedule.status || 'upcoming';
      
      // 處理時間格式
      if (schedule.time) {
        const date = new Date(schedule.time);
        const formattedDateTime = date.toISOString().slice(0, 16);
        document.getElementById('schedule-time').value = formattedDateTime;
      }
      
      // 設置所屬比賽（可能需要等待比賽選項載入完成）
      setTimeout(() => {
        if (schedule.matchId) {
          document.getElementById('schedule-match').value = schedule.matchId;
        }
      }, 500);
      
      document.getElementById('schedule-modal-title').textContent = '編輯賽程';
      
      // 顯示模態框
      const scheduleModal = new bootstrap.Modal(document.getElementById('schedule-modal'));
      scheduleModal.show();
    } else {
      alert('找不到該賽程數據');
    }
  }).catch((error) => {
    console.error('獲取賽程數據失敗:', error);
    alert('獲取賽程數據失敗，請稍後再試');
  });
}

// 刪除賽程
function deleteSchedule(scheduleId) {
  if (confirm('確定要刪除此賽程嗎？此操作不可撤銷。')) {
    const db = firebase.firestore();
    db.collection('schedules').doc(scheduleId).delete().then(() => {
      alert('賽程已成功刪除');
      fetchSchedules();
    }).catch((error) => {
      console.error('刪除賽程失敗:', error);
      alert('刪除賽程失敗，請稍後再試');
    });
  }
}

// 保存比賽數據
function saveMatch() {
  const matchId = document.getElementById('match-id').value;
  const tournamentSelect = document.getElementById('match-tournament');
  let tournamentId = '';
  let tournamentName = '';
  
  // 檢查是否選擇了賽程
  if (tournamentSelect && tournamentSelect.value) {
    tournamentId = tournamentSelect.value;
    tournamentName = tournamentSelect.options[tournamentSelect.selectedIndex].text;
  }
  
  const matchData = {
    name: document.getElementById('match-name').value,
    type: document.getElementById('match-type').value,
    status: document.getElementById('match-status').value,
    description: document.getElementById('match-description').value,
    startDate: new Date(document.getElementById('match-start-date').value).toISOString(),
    updatedAt: new Date().toISOString(),
    tournamentId: tournamentId,
    tournamentName: tournamentName
  };
  
  const db = firebase.firestore();
  
  if (matchId) {
    // 更新現有比賽
    db.collection('matches').doc(matchId).update(matchData).then(() => {
      alert('比賽已成功更新');
      fetchMatches();
      fetchSchedules(); // 同時更新賽程顯示，因為比賽可能已關聯到賽程
      // 關閉模態框
      const matchModal = bootstrap.Modal.getInstance(document.getElementById('match-modal'));
      matchModal.hide();
    }).catch((error) => {
      console.error('更新比賽失敗:', error);
      alert('更新比賽失敗，請稍後再試');
    });
  } else {
    // 創建新比賽
    matchData.createdAt = new Date().toISOString();
    db.collection('matches').add(matchData).then(() => {
      alert('比賽已成功創建');
      fetchMatches();
      fetchSchedules(); // 同時更新賽程顯示，因為比賽可能已關聯到賽程
      // 關閉模態框
      const matchModal = bootstrap.Modal.getInstance(document.getElementById('match-modal'));
      matchModal.hide();
    }).catch((error) => {
      console.error('創建比賽失敗:', error);
      alert('創建比賽失敗，請稍後再試');
    });
  }
}

// 保存賽程數據
function saveSchedule() {
  const scheduleId = document.getElementById('schedule-id').value;
  const matchId = document.getElementById('schedule-match').value;
  const matchName = document.getElementById('schedule-match').options[document.getElementById('schedule-match').selectedIndex].text;
  
  if (!matchId) {
    alert('請選擇所屬比賽');
    return;
  }
  
  const scheduleData = {
    matchId: matchId,
    matchName: matchName,
    round: document.getElementById('schedule-round').value,
    location: document.getElementById('schedule-location').value,
    status: document.getElementById('schedule-status').value,
    time: new Date(document.getElementById('schedule-time').value).toISOString(),
    updatedAt: new Date().toISOString()
  };
  
  const db = firebase.firestore();
  
  if (scheduleId) {
    // 更新現有賽程
    db.collection('schedules').doc(scheduleId).update(scheduleData).then(() => {
      alert('賽程已成功更新');
      fetchSchedules();
      // 關閉模態框
      const scheduleModal = bootstrap.Modal.getInstance(document.getElementById('schedule-modal'));
      scheduleModal.hide();
    }).catch((error) => {
      console.error('更新賽程失敗:', error);
      alert('更新賽程失敗，請稍後再試');
    });
  } else {
    // 創建新賽程
    scheduleData.createdAt = new Date().toISOString();
    db.collection('schedules').add(scheduleData).then(() => {
      alert('賽程已成功創建');
      fetchSchedules();
      // 關閉模態框
      const scheduleModal = bootstrap.Modal.getInstance(document.getElementById('schedule-modal'));
      scheduleModal.hide();
    }).catch((error) => {
      console.error('創建賽程失敗:', error);
      alert('創建賽程失敗，請稍後再試');
    });
  }
}