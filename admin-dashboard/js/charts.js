// Chart.js Configuration - Clean Professional Style
let statusChart = null;
let timeChart = null;
let topDesignersChart = null;
let likesChart = null;

// Chart.js Default Configuration
Chart.defaults.font.family = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
Chart.defaults.font.size = 12;
Chart.defaults.color = '#64748B';

// Render All Charts
function renderCharts() {
    renderStatusChart();
    renderTimeChart();
}

// Render Status Distribution Chart (Doughnut) - Compact Version
function renderStatusChart() {
    const ctx = document.getElementById('statusChart');
    if (!ctx) return;
    
    const pendingCount = allDesigns.filter(d => d.status === 'pending').length;
    const approvedCount = allDesigns.filter(d => d.status === 'approved').length;
    const rejectedCount = allDesigns.filter(d => d.status === 'rejected').length;
    
    if (statusChart) {
        statusChart.destroy();
    }
    
    statusChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Pending', 'Approved', 'Rejected'],
            datasets: [{
                data: [pendingCount, approvedCount, rejectedCount],
                backgroundColor: [
                    '#F59E0B',
                    '#10B981',
                    '#F43F5E'
                ],
                borderColor: '#FFFFFF',
                borderWidth: 3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        color: '#334155',
                        font: {
                            size: 12,
                            weight: '600'
                        },
                        padding: 15,
                        usePointStyle: true,
                        pointStyle: 'circle'
                    }
                },
                tooltip: {
                    backgroundColor: '#0F172A',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: '#CBD5E1',
                    borderWidth: 1,
                    padding: 12,
                    displayColors: true,
                    callbacks: {
                        label: function(context) {
                            const label = context.label || '';
                            const value = context.parsed || 0;
                            const total = context.dataset.data.reduce((a, b) => a + b, 0);
                            const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                            return `${label}: ${value} (${percentage}%)`;
                        }
                    }
                }
            }
        }
    });
}

// Render Submissions Over Time Chart (Line) - Compact Version
function renderTimeChart() {
    const ctx = document.getElementById('timeChart');
    if (!ctx) return;
    
    // Get submissions data for last 30 days
    const last30Days = Array.from({ length: 30 }, (_, i) => {
        const date = new Date();
        date.setDate(date.getDate() - (29 - i));
        return date.toISOString().split('T')[0];
    });
    
    const submissionsByDate = {};
    last30Days.forEach(date => {
        submissionsByDate[date] = 0;
    });
    
    allDesigns.forEach(design => {
        const designDate = design.created_at?.split('T')[0];
        if (submissionsByDate.hasOwnProperty(designDate)) {
            submissionsByDate[designDate]++;
        }
    });
    
    const labels = last30Days.map(date => {
        const d = new Date(date);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    });
    
    const data = last30Days.map(date => submissionsByDate[date]);
    
    if (timeChart) {
        timeChart.destroy();
    }
    
    timeChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Submissions',
                data: data,
                borderColor: '#475569',
                backgroundColor: 'rgba(71, 85, 105, 0.10)',
                fill: true,
                tension: 0.4,
                pointBackgroundColor: '#475569',
                pointBorderColor: '#FFFFFF',
                pointBorderWidth: 2,
                pointRadius: 3,
                pointHoverRadius: 5
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: '#0F172A',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: '#CBD5E1',
                    borderWidth: 1,
                    padding: 10,
                    displayColors: false,
                    callbacks: {
                        title: function(context) {
                            return context[0].label;
                        },
                        label: function(context) {
                            const value = context.parsed.y;
                            return `${value} submission${value !== 1 ? 's' : ''}`;
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        color: '#77766E',
                        font: {
                            size: 11
                        },
                        stepSize: 1
                    },
                    grid: {
                        color: '#EAE7DF',
                        drawBorder: false
                    }
                },
                x: {
                    ticks: {
                        color: '#77766E',
                        font: {
                            size: 10
                        },
                        maxRotation: 45,
                        minRotation: 45
                    },
                    grid: {
                        display: false,
                        drawBorder: false
                    }
                }
            }
        }
    });
}

// Top Designers Chart - Compact Horizontal Bar
function renderTopDesignersChart() {
    const ctx = document.getElementById('topDesignersChart');
    if (!ctx) return;
    
    const designerCounts = {};
    allDesigns.forEach(design => {
        const designerId = design.designer_id;
        const designerName = design.designer?.brand_name || 'Unknown';
        
        if (!designerCounts[designerId]) {
            designerCounts[designerId] = {
                name: designerName,
                count: 0
            };
        }
        designerCounts[designerId].count++;
    });
    
    const sortedDesigners = Object.values(designerCounts)
        .sort((a, b) => b.count - a.count)
        .slice(0, 5);
    
    const labels = sortedDesigners.map(d => d.name.length > 15 ? d.name.substring(0, 15) + '...' : d.name);
    const data = sortedDesigners.map(d => d.count);
    
    if (topDesignersChart) {
        topDesignersChart.destroy();
    }
    
    topDesignersChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Designs',
                data: data,
                backgroundColor: [
                    '#334155',
                    '#475569',
                    '#64748B',
                    '#94A3B8',
                    '#CBD5E1'
                ],
                borderRadius: 6,
                borderSkipped: false
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            indexAxis: 'y',
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: '#0F172A',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: '#475569',
                    borderWidth: 1,
                    padding: 10
                }
            },
            scales: {
                y: {
                    ticks: {
                        color: '#26251F',
                        font: {
                            size: 11,
                            weight: '600'
                        }
                    },
                    grid: {
                        display: false,
                        drawBorder: false
                    }
                },
                x: {
                    beginAtZero: true,
                    ticks: {
                        color: '#77766E',
                        font: {
                            size: 10
                        },
                        stepSize: 1
                    },
                    grid: {
                        color: '#EAE7DF',
                        drawBorder: false
                    }
                }
            }
        }
    });
}

// Most Liked Designs Chart - Compact Vertical Bar
function renderLikesDistributionChart() {
    const ctx = document.getElementById('likesChart');
    if (!ctx) return;
    
    const approvedDesigns = allDesigns
        .filter(d => d.status === 'approved')
        .sort((a, b) => (b.likes_count || 0) - (a.likes_count || 0))
        .slice(0, 10);
    
    const labels = approvedDesigns.map(d => {
        const title = d.title;
        return title.length > 12 ? title.substring(0, 12) + '...' : title;
    });
    const data = approvedDesigns.map(d => d.likes_count || 0);
    
    if (likesChart) {
        likesChart.destroy();
    }
    
    likesChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Likes',
                data: data,
                backgroundColor: 'rgba(71, 85, 105, 0.8)',
                borderColor: '#475569',
                borderWidth: 0,
                borderRadius: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: '#0F172A',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: '#475569',
                    borderWidth: 1,
                    padding: 10,
                    callbacks: {
                        label: function(context) {
                            return `❤️ ${context.parsed.y} likes`;
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        color: '#77766E',
                        font: {
                            size: 10
                        },
                        stepSize: 1
                    },
                    grid: {
                        color: '#EAE7DF',
                        drawBorder: false
                    }
                },
                x: {
                    ticks: {
                        color: '#77766E',
                        font: {
                            size: 10
                        },
                        maxRotation: 45,
                        minRotation: 45
                    },
                    grid: {
                        display: false,
                        drawBorder: false
                    }
                }
            }
        }
    });
}