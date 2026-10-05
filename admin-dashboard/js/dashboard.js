// Global variables
let allDesigns = [];
let allDesigners = [];
let allFeedback = [];
let currentSection = 'overview';
let designFilter = 'pending';
let applicationFilter = 'pending';
let feedbackSort = 'newest';

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (character) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
    })[character]);
}

function safeImageUrl(value) {
    try {
        const url = new URL(value);
        return ['http:', 'https:'].includes(url.protocol) ? escapeHtml(url.href) : '';
    } catch {
        return '';
    }
}

function safeExternalUrl(value) {
    try {
        const url = new URL(value);
        return ['http:', 'https:'].includes(url.protocol) ? escapeHtml(url.href) : '';
    } catch {
        return '';
    }
}

function showDashboardError(message) {
    let banner = document.getElementById('dashboard-error');
    if (!banner) {
        banner = document.createElement('div');
        banner.id = 'dashboard-error';
        banner.setAttribute('role', 'alert');
        banner.className = 'mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800';
        const header = document.querySelector('main header');
        header?.insertAdjacentElement('afterend', banner);
    }
    banner.textContent = message;
    banner.classList.remove('hidden');
}

function clearDashboardError() {
    document.getElementById('dashboard-error')?.classList.add('hidden');
}

async function checkAuth() {
    try {
        const { data, error } = await closetxSupabase.auth.getSession();
        if (error) throw error;
        if (!data.session) {
            window.location.replace('login.html');
            return false;
        }

        if (!(await isClosetXAdmin())) {
            const { error: signOutError } = await closetxSupabase.auth.signOut();
            if (signOutError) throw signOutError;
            window.location.replace('login.html');
            return false;
        }

        updateAdminIdentity(data.session);
        return true;
    } catch (error) {
        console.error('Admin authorization failed:', error);
        showDashboardError(`Could not verify admin access: ${error.message}`);
        return false;
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    bindDashboardControls();
    if (await checkAuth()) {
        await loadDashboard();
    }
});

function bindDashboardControls() {
    document.getElementById('global-search')?.addEventListener('input', applyCurrentSearch);
    document.getElementById('notification-button')?.addEventListener('click', () => {
        const pendingApplications = Number(document.getElementById('applications-badge')?.textContent || 0);
        const target = pendingApplications ? 'applications' : 'pending';
        if (target === 'applications') {
            applicationFilter = 'pending';
            document.querySelectorAll('[data-application-filter]').forEach((tab) => tab.classList.toggle('active', tab.dataset.applicationFilter === 'pending'));
        } else {
            designFilter = 'pending';
            document.querySelectorAll('[data-design-filter]').forEach((tab) => tab.classList.toggle('active', tab.dataset.designFilter === 'pending'));
        }
        showSection(target);
    });
    document.querySelectorAll('[data-design-filter]').forEach((button) => {
        button.addEventListener('click', () => {
            designFilter = button.dataset.designFilter;
            document.querySelectorAll('[data-design-filter]').forEach((tab) => tab.classList.toggle('active', tab === button));
            renderPendingDesigns();
        });
    });
    document.querySelectorAll('[data-application-filter]').forEach((button) => {
        button.addEventListener('click', () => {
            applicationFilter = button.dataset.applicationFilter;
            document.querySelectorAll('[data-application-filter]').forEach((tab) => tab.classList.toggle('active', tab === button));
            renderApplications();
        });
    });
    document.querySelectorAll('[data-feedback-filter]').forEach((button) => {
        button.addEventListener('click', () => {
            feedbackSort = button.dataset.feedbackFilter;
            document.querySelectorAll('[data-feedback-filter]').forEach((tab) => tab.classList.toggle('active', tab === button));
            renderFeedback();
        });
    });
    document.addEventListener('keydown', (event) => {
        if (event.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) {
            event.preventDefault();
            document.getElementById('global-search')?.focus();
        }
    });
}

function applyCurrentSearch() {
    const query = document.getElementById('global-search')?.value.trim().toLowerCase() || '';
    const visibleSection = document.getElementById(`${currentSection}-section`);
    visibleSection?.querySelectorAll('[data-searchable]').forEach((row) => {
        row.classList.toggle('hidden', !row.textContent.toLowerCase().includes(query));
    });
}

function updateAdminIdentity(session) {
    const email = session?.user?.email || 'Administrator';
    const initials = email.split('@')[0].split(/[._-]/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || 'AD';
    for (const id of ['admin-name', 'topbar-admin-name']) {
        const element = document.getElementById(id);
        if (element) element.textContent = email;
    }
    for (const id of ['admin-avatar', 'topbar-avatar']) {
        const element = document.getElementById(id);
        if (element) element.textContent = initials;
    }
}

// Load Dashboard
async function loadDashboard() {
    clearDashboardError();
    try {
        await Promise.all([loadStats(), loadDesigns(), loadDesigners(), loadFeedback()]);
        renderCharts();
        showSection(currentSection);
    } catch (error) {
        console.error('Could not load admin dashboard:', error);
        showDashboardError(`Could not load dashboard data: ${error.message}`);
    }
}

// Load Statistics
async function loadStats() {
    try {
        const [
            pendingResult,
            approvedResult,
            rejectedResult,
            applicationsResult,
            approvedDesignersResult,
            feedbackResult
        ] = await Promise.all([
            closetxSupabase.from('designs').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
            closetxSupabase.from('designs').select('*', { count: 'exact', head: true }).eq('status', 'approved'),
            closetxSupabase.from('designs').select('*', { count: 'exact', head: true }).eq('status', 'rejected'),
            closetxSupabase.from('designer_profiles').select('*', { count: 'exact', head: true }).eq('application_status', 'pending'),
            closetxSupabase.from('designer_profiles').select('*', { count: 'exact', head: true }).eq('application_status', 'approved'),
            closetxSupabase.from('design_comments').select('*', { count: 'exact', head: true })
        ]);
        
        const results = [pendingResult, approvedResult, rejectedResult, applicationsResult, approvedDesignersResult, feedbackResult];
        const failedResult = results.find((result) => result.error);
        if (failedResult) throw failedResult.error;

        const stats = {
            pending: pendingResult.count ?? 0,
            approved: approvedResult.count ?? 0,
            rejected: rejectedResult.count ?? 0,
            applications: applicationsResult.count ?? 0,
            designers: approvedDesignersResult.count ?? 0,
            feedback: feedbackResult.count ?? 0
        };
        
        renderStatsCards(stats);
        updateBadges(stats);
        
    } catch (error) {
        throw new Error(`Could not load design statistics: ${error.message}`);
    }
}

// Render Stats Cards
function renderStatsCards(stats) {
    const statsCards = document.getElementById('stats-cards');
    statsCards.innerHTML = `
        <button type="button" onclick="showSection('applications')" class="metric-card">
            <span class="metric-icon metric-amber"><i class="fas fa-id-card"></i></span>
            <span><strong>${stats.applications}</strong><small>Pending applications</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('pending')" class="metric-card">
            <span class="metric-icon metric-slate"><i class="fas fa-images"></i></span>
            <span><strong>${stats.pending}</strong><small>Asset requests</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('designers')" class="metric-card">
            <span class="metric-icon metric-emerald"><i class="fas fa-users"></i></span>
            <span><strong>${stats.designers}</strong><small>Approved designers</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('feedback')" class="metric-card">
            <span class="metric-icon metric-slate"><i class="fas fa-comment-dots"></i></span>
            <span><strong>${stats.feedback}</strong><small>Design feedback</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
    `;
}

// Update Navigation Badges
function updateBadges(stats) {
    document.getElementById('pending-badge').textContent = stats.pending;
    document.getElementById('applications-badge').textContent = stats.applications;
    document.getElementById('feedback-badge').textContent = stats.feedback;
    document.getElementById('notification-count').textContent = stats.applications + stats.pending;
    document.getElementById('notification-button').setAttribute('aria-label', `${stats.applications} pending designer applications and ${stats.pending} pending design requests`);
    document.getElementById('pending-filter-count').textContent = stats.pending;
    document.getElementById('application-filter-count').textContent = stats.applications;
}

// Load All Designs
async function loadDesigns() {
    try {
        const { data: designs, error } = await closetxSupabase
            .from('designs')
            .select('id, designer_id, title, description, front_image_url, back_image_url, price, category, status, lens_id, lens_group_id, rejection_reason, likes_count, views_count, created_at, updated_at')
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        allDesigns = designs || [];
        
        const designerIds = [...new Set(allDesigns.map((design) => design.designer_id).filter(Boolean))];
        let designers = [];
        if (designerIds.length > 0) {
            const { data, error: designerError } = await closetxSupabase
                .from('designer_profiles')
                .select('id, user_id, brand_name, location, bio, profile_image_url, is_verified, created_at')
                .in('user_id', designerIds);
            if (designerError) throw designerError;
            designers = data || [];
        }
        
        const designersMap = new Map(designers.map((designer) => [designer.user_id, designer]));
        
        allDesigns = allDesigns.map(design => ({
            ...design,
            designer: designersMap.get(design.designer_id)
        }));
        
        renderRecentActivity();
        
    } catch (error) {
        throw new Error(`Could not load designs and designer profiles: ${error.message}`);
    }
}

async function loadDesigners() {
    const { data, error } = await closetxSupabase
        .from('designer_profiles')
        .select('id, user_id, brand_name, location, bio, profile_image_url, is_verified, application_status, application_rejection_reason, created_at, shopee_link, tiktok_link, lazada_link, facebook_link, instagram_link, twitter_link, website_link')
        .order('created_at', { ascending: false });
    if (error) throw new Error(`Could not load designer profiles: ${error.message}`);
    const designerProfiles = data || [];
    const userIds = [...new Set(designerProfiles.map((designer) => designer.user_id).filter(Boolean))];
    let profiles = [];
    if (userIds.length) {
        const { data: profileData, error: profileError } = await closetxSupabase
            .from('profiles')
            .select('id, full_name, email')
            .in('id', userIds);
        if (profileError) throw new Error(`Could not load applicant account details: ${profileError.message}`);
        profiles = profileData || [];
    }
    const profilesById = new Map(profiles.map((profile) => [profile.id, profile]));
    allDesigners = designerProfiles.map((designer) => ({
        ...designer,
        profile: profilesById.get(designer.user_id)
    }));
}

async function loadFeedback() {
    const { data: comments, error } = await closetxSupabase
        .from('design_comments')
        .select('id, design_id, user_id, comment_text, rating, created_at')
        .order('created_at', { ascending: false });
    if (error) throw new Error(`Could not load customer feedback: ${error.message}`);

    const designIds = [...new Set((comments || []).map((comment) => comment.design_id).filter(Boolean))];
    const userIds = [...new Set((comments || []).map((comment) => comment.user_id).filter(Boolean))];
    const [designResult, profileResult] = await Promise.all([
        designIds.length
            ? closetxSupabase.from('designs').select('id, title').in('id', designIds)
            : Promise.resolve({ data: [], error: null }),
        userIds.length
            ? closetxSupabase.from('profiles').select('id, full_name, email').in('id', userIds)
            : Promise.resolve({ data: [], error: null })
    ]);
    if (designResult.error) throw new Error(`Could not load designs for feedback: ${designResult.error.message}`);
    if (profileResult.error) throw new Error(`Could not load feedback authors: ${profileResult.error.message}`);

    const designsById = new Map((designResult.data || []).map((design) => [design.id, design]));
    const profilesById = new Map((profileResult.data || []).map((profile) => [profile.id, profile]));
    allFeedback = (comments || []).map((comment) => ({
        ...comment,
        design: designsById.get(comment.design_id),
        author: profilesById.get(comment.user_id)
    }));
}

// Render Recent Activity
function renderRecentActivity() {
    const recentActivity = document.getElementById('recent-activity');
    const recentDesigns = allDesigns.slice(0, 5);
    
    if (recentDesigns.length === 0) {
        recentActivity.innerHTML = '<div class="empty-state"><h3>No design requests yet</h3><p>New submissions will appear here.</p></div>';
        return;
    }
    
    recentActivity.innerHTML = `<table class="admin-table">
        <thead><tr><th>Design</th><th>Designer</th><th>Submitted</th><th>Status</th></tr></thead>
        <tbody>${recentDesigns.map((design) => `<tr data-searchable>
            <td><div class="table-identity"><img src="${safeImageUrl(design.front_image_url)}" alt="" class="table-thumbnail"><div><strong>${escapeHtml(design.title)}</strong><small>${escapeHtml(design.category || 'Uncategorized')}</small></div></div></td>
            <td>${escapeHtml(design.designer?.brand_name || 'Unknown designer')}</td>
            <td>${escapeHtml(new Date(design.created_at).toLocaleDateString())}</td>
            <td><span class="status-pill status-${escapeHtml(design.status)}">${escapeHtml(design.status === 'rejected' ? 'Declined' : design.status)}</span></td>
        </tr>`).join('')}</tbody>
    </table>`;
}

// Get Status Color
function getStatusColor(status) {
    switch(status) {
        case 'pending': return 'bg-yellow-500/20 text-yellow-500';
        case 'approved': return 'bg-cyan-500/20 text-cyan-500';
        case 'rejected': return 'bg-red-500/20 text-red-500';
        default: return 'bg-gray-500/20 text-gray-500';
    }
}

// Show Section
function showSection(section) {
    currentSection = section;
    
    // Update navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    document.getElementById(`nav-${section}`).classList.add('active');
    
    // Hide all sections
    document.querySelectorAll('.section').forEach(sec => {
        sec.classList.add('hidden');
    });
    
    // Update header
    const titles = {
        overview: { title: 'Overview', subtitle: 'Dashboard analytics and insights' },
        pending: { title: 'Asset approvals', subtitle: 'Review uploaded designs, inspect details, and make a decision' },
        applications: { title: 'Designer Applications', subtitle: 'Review applications to join ClosetX as a designer' },
        designers: { title: 'Designers', subtitle: 'Approved designer profiles' },
        feedback: { title: 'Customer Feedback', subtitle: 'Ratings and comments on designs' }
    };
    
    document.getElementById('page-title').textContent = titles[section].title;
    document.getElementById('page-subtitle').textContent = titles[section].subtitle;
    
    // Show selected section
    const sectionElement = document.getElementById(`${section}-section`);
    if (sectionElement) {
        sectionElement.classList.remove('hidden');
        
        // Render section content
        switch(section) {
            case 'pending':
                renderPendingDesigns();
                break;
            case 'designers':
                renderDesigners();
                break;
            case 'applications':
                renderApplications();
                break;
            case 'feedback':
                renderFeedback();
                break;
        }
        applyCurrentSearch();
    }
}

// Render Pending Designs (Organized by Designer)
function renderPendingDesigns() {
    const container = document.getElementById('pending-designs');
    const designs = designFilter === 'all'
        ? allDesigns
        : allDesigns.filter((design) => design.status === designFilter);
    document.getElementById('asset-results-count').textContent = `${designs.length} ${designs.length === 1 ? 'asset' : 'assets'}`;

    if (designs.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <span class="empty-state-icon"><i class="far fa-images"></i></span>
                <h3>No ${designFilter === 'pending' ? 'pending assets' : `${escapeHtml(designFilter)} assets`}</h3>
                <p>${designFilter === 'pending' ? 'New design submissions will appear here for review.' : 'There are no matching design requests.'}</p>
            </div>
        `;
        return;
    }

    container.innerHTML = `
        <table class="admin-table">
            <thead><tr><th>Asset</th><th>Designer</th><th>Category</th><th>Submitted</th><th>Status</th><th></th></tr></thead>
            <tbody>${designs.map((design) => `
                <tr data-searchable>
                    <td>
                        <div class="table-identity">
                            <img src="${safeImageUrl(design.front_image_url)}" alt="" class="table-thumbnail">
                            <div><strong>${escapeHtml(design.title)}</strong><small>₱${escapeHtml(Number(design.price || 0).toLocaleString())}</small></div>
                        </div>
                    </td>
                    <td>${escapeHtml(design.designer?.brand_name || 'Unknown designer')}</td>
                    <td><span class="category-tag">${escapeHtml(design.category || 'Uncategorized')}</span></td>
                    <td>${escapeHtml(new Date(design.created_at).toLocaleDateString())}</td>
                    <td><span class="status-pill status-${escapeHtml(design.status)}">${escapeHtml(design.status === 'rejected' ? 'Declined' : design.status)}</span></td>
                    <td><button type="button" data-design-id="${escapeHtml(design.id)}" class="row-action">${design.status === 'pending' ? 'Inspect request' : 'View details'} <i class="fas fa-arrow-right"></i></button></td>
                </tr>
            `).join('')}</tbody>
        </table>
    `;
    bindDesignCardActions(container);
    applyCurrentSearch();
}

function renderApplications() {
    const container = document.getElementById('applications-list');
    const filtered = allDesigners.filter((designer) => applicationFilter === 'all'
        || (designer.application_status || (designer.is_verified ? 'approved' : 'pending')) === applicationFilter);

    if (!filtered.length) {
        container.innerHTML = `<div class="empty-state"><span class="empty-state-icon"><i class="far fa-id-card"></i></span><h3>No ${applicationFilter === 'pending' ? 'pending applications' : 'applications found'}</h3><p>Designer applications will appear here when submitted.</p></div>`;
        return;
    }

    container.innerHTML = `
        <table class="admin-table">
            <thead><tr><th>Applicant</th><th>Location</th><th>Portfolio</th><th>Applied</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>${filtered.map((designer) => {
                const status = designer.application_status || (designer.is_verified ? 'approved' : 'pending');
                const applicant = designer.profile?.full_name || designer.profile?.email || 'Designer applicant';
                const portfolio = designer.website_link || designer.instagram_link || designer.tiktok_link;
                return `
                    <tr data-searchable>
                        <td>
                            <div class="table-identity">
                                <div class="table-avatar">${designer.profile_image_url ? `<img src="${safeImageUrl(designer.profile_image_url)}" alt="">` : escapeHtml((designer.brand_name || applicant).slice(0, 2).toUpperCase())}</div>
                                <div><strong>${escapeHtml(designer.brand_name || 'Unnamed brand')}</strong><small>${escapeHtml(applicant)}</small></div>
                            </div>
                        </td>
                        <td>${escapeHtml(designer.location || '—')}</td>
                        <td>${portfolio ? `<a class="portfolio-link" href="${safeExternalUrl(portfolio)}" target="_blank" rel="noopener noreferrer">View portfolio <i class="fas fa-arrow-up-right-from-square"></i></a>` : '<span class="text-gray-400">Not provided</span>'}</td>
                        <td>${escapeHtml(new Date(designer.created_at).toLocaleDateString())}</td>
                        <td><span class="status-pill status-${escapeHtml(status)}">${escapeHtml(status === 'approved' ? 'Accepted' : status === 'rejected' ? 'Declined' : 'Pending')}</span></td>
                        <td><div class="row-actions">
                            <button type="button" data-application-id="${escapeHtml(designer.id)}" class="row-action">Details</button>
                            ${status === 'pending' ? `<button type="button" data-application-decline="${escapeHtml(designer.id)}" class="row-action row-action-danger">Decline</button><button type="button" data-application-accept="${escapeHtml(designer.id)}" class="row-action row-action-primary">Accept</button>` : ''}
                        </div></td>
                    </tr>
                `;
            }).join('')}</tbody>
        </table>
    `;

    container.querySelectorAll('[data-application-id], [data-application-accept], [data-application-decline]').forEach((button) => {
        button.addEventListener('click', () => {
            const id = button.dataset.applicationId || button.dataset.applicationAccept || button.dataset.applicationDecline;
            if (button.hasAttribute('data-application-accept')) {
                if (window.confirm('Accept this designer application?')) reviewDesignerApplication(id, 'approved');
                return;
            }
            openApplicationModal(id);
        });
    });
    applyCurrentSearch();
}

function openApplicationModal(applicationId) {
    const designer = allDesigners.find((item) => item.id === applicationId);
    if (!designer) return;

    const modal = document.getElementById('applicationModal');
    const isPending = designer.application_status === 'pending';
    const accountName = designer.profile?.full_name || 'Name not provided';
    const socialLinks = [
        ['Website', designer.website_link],
        ['Shopee', designer.shopee_link],
        ['TikTok', designer.tiktok_link],
        ['Lazada', designer.lazada_link],
        ['Facebook', designer.facebook_link],
        ['Instagram', designer.instagram_link],
        ['Twitter', designer.twitter_link]
    ].filter(([, url]) => safeExternalUrl(url));

    modal.innerHTML = `
        <div class="flex items-center justify-between border-b border-gray-200 p-5">
            <div>
                <h2 class="text-xl font-bold text-gray-900">Designer application</h2>
                <p class="text-sm text-gray-500">${escapeHtml(designer.brand_name || 'Unnamed brand')}</p>
            </div>
            <button type="button" data-close-application class="px-3 py-2 text-gray-500" aria-label="Close application">✕</button>
        </div>
        <div class="space-y-5 p-5">
            <div class="flex items-center gap-4">
                ${designer.profile_image_url
                    ? `<img src="${safeImageUrl(designer.profile_image_url)}" alt="" class="h-16 w-16 rounded-full object-cover">`
                    : '<div class="flex h-16 w-16 items-center justify-center rounded-full bg-gray-700 text-xl font-bold">✦</div>'}
                <div>
                    <h3 class="font-semibold text-gray-900">${escapeHtml(accountName)}</h3>
                    <p class="text-sm text-gray-500">${escapeHtml(designer.profile?.email || 'No email')}</p>
                    <p class="text-sm text-gray-500">${escapeHtml(designer.location || 'Location not provided')}</p>
                </div>
            </div>
            <div class="rounded-xl bg-gray-50 p-4">
                <h3 class="mb-2 font-semibold text-gray-900">About the designer</h3>
                <p class="whitespace-pre-wrap text-sm text-gray-700">${escapeHtml(designer.bio || 'No biography provided.')}</p>
            </div>
            ${socialLinks.length ? `
                <div>
                    <h3 class="mb-2 font-semibold text-gray-900">Portfolio and links</h3>
                    <ul class="space-y-1 text-sm">
                        ${socialLinks.map(([label, url]) => `<li><a class="text-cyan-600 underline" href="${safeExternalUrl(url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label)}</a></li>`).join('')}
                    </ul>
                </div>
            ` : ''}
            ${designer.application_rejection_reason ? `
                <div class="rounded-xl bg-red-50 p-4 text-sm text-red-800">
                    <strong>Previous decision:</strong> ${escapeHtml(designer.application_rejection_reason)}
                </div>
            ` : ''}
            ${isPending ? `
                <label class="block text-sm font-medium text-gray-700" for="applicationRejectionReason">
                    Feedback note (optional)
                    <textarea id="applicationRejectionReason" rows="3" class="mt-2 w-full rounded-xl border border-gray-200 bg-white p-3" placeholder="Explain what needs to be addressed"></textarea>
                </label>
                <div id="applicationModalError" class="hidden rounded-xl bg-red-50 p-3 text-sm text-red-800" role="alert"></div>
            ` : ''}
        </div>
        <div class="flex gap-3 border-t border-gray-200 p-5">
            ${isPending ? `
                <button type="button" data-decline-application class="flex-1 rounded-xl bg-red-600 px-4 py-3 font-semibold text-white">Decline</button>
                <button type="button" data-approve-application class="flex-1 rounded-xl bg-green-700 px-4 py-3 font-semibold text-white">Accept application</button>
            ` : '<button type="button" data-close-application class="flex-1 rounded-xl bg-gray-100 px-4 py-3 font-semibold text-gray-900">Close</button>'}
        </div>
    `;
    modal.classList.remove('hidden');
    modal.querySelectorAll('[data-close-application]').forEach((button) => button.addEventListener('click', closeApplicationModal));
    modal.querySelector('[data-approve-application]')?.addEventListener('click', () => reviewDesignerApplication(applicationId, 'approved'));
    modal.querySelector('[data-decline-application]')?.addEventListener('click', () => reviewDesignerApplication(applicationId, 'rejected'));
}

function closeApplicationModal() {
    document.getElementById('applicationModal').classList.add('hidden');
}

async function reviewDesignerApplication(applicationId, status) {
    const errorElement = document.getElementById('applicationModalError');
    const reason = document.getElementById('applicationRejectionReason')?.value.trim() || '';
    try {
        const { data, error } = await closetxSupabase
            .from('designer_profiles')
            .update({
                application_status: status,
                application_rejection_reason: status === 'rejected' ? reason : null,
                is_verified: status === 'approved'
            })
            .eq('id', applicationId)
            .eq('application_status', 'pending')
            .select('id');
        if (error) throw error;
        if (!data?.length) throw new Error('This application has already been reviewed or is no longer available.');

        closeApplicationModal();
        await refreshData();
    } catch (error) {
        console.error('Could not review designer application:', error);
        if (errorElement) {
            errorElement.textContent = `Could not save the review: ${error.message}`;
            errorElement.classList.remove('hidden');
        } else {
            showDashboardError(`Could not save the application decision: ${error.message}`);
        }
    }
}

function bindDesignCardActions(container) {
    container.querySelectorAll('[data-design-id]').forEach((button) => {
        button.addEventListener('click', () => openApprovalModalById(button.dataset.designId));
    });
}

function openApprovalModalById(designId) {
    const design = allDesigns.find((item) => item.id === designId);
    if (design) openApprovalModal(design);
}

// Render Design Card
function renderDesignCard(design, showLensId = false, showRejection = false) {
    return `
        <div class="bg-gray-800 border border-gray-700 rounded-2xl overflow-hidden hover:border-cyan-500 transition transform hover:-translate-y-1">
            <!-- Images -->
            <div class="grid grid-cols-2 gap-2 p-4 bg-gray-900">
                <img src="${safeImageUrl(design.front_image_url)}" alt="Front" class="w-full h-48 object-cover rounded-xl">
                <img src="${safeImageUrl(design.back_image_url)}" alt="Back" class="w-full h-48 object-cover rounded-xl">
            </div>
            
            <!-- Info -->
            <div class="p-5">
                <div class="flex justify-between items-start mb-3">
                    <div>
                        <h3 class="text-lg font-bold text-white mb-1">${escapeHtml(design.title)}</h3>
                        <p class="text-gray-400 text-sm">by ${escapeHtml(design.designer?.brand_name || 'Unknown')}</p>
                    </div>
                    <div class="text-xl font-bold text-cyan-500">₱${escapeHtml(Number(design.price || 0).toLocaleString())}</div>
                </div>
                
                ${design.description ? `<p class="text-gray-400 text-sm mb-3 line-clamp-2">${escapeHtml(design.description)}</p>` : ''}
                
                <div class="flex items-center gap-2 mb-3 text-gray-500 text-xs">
                    ${design.category ? `<span class="px-2 py-1 bg-gray-700 rounded-lg">${escapeHtml(design.category)}</span>` : ''}
                    <span class="flex items-center gap-1">
                        <i class="fas fa-heart text-red-500"></i>
                        ${escapeHtml(design.likes_count || 0)}
                    </span>
                    <span class="flex items-center gap-1">
                        <i class="fas fa-calendar"></i>
                        ${escapeHtml(new Date(design.created_at).toLocaleDateString())}
                    </span>
                </div>
                
                ${showLensId && design.lens_id ? `
                    <div class="mb-3 p-2 bg-cyan-500/10 border border-cyan-500/30 rounded-lg">
                        <p class="text-xs text-gray-400">Lens ID:</p>
                        <p class="text-sm text-cyan-500 font-mono">${escapeHtml(design.lens_id)}</p>
                    </div>
                ` : ''}
                
                ${showRejection && design.rejection_reason ? `
                    <div class="mb-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                        <p class="text-xs text-red-500 font-semibold mb-1">Rejection Reason:</p>
                        <p class="text-xs text-gray-300">${escapeHtml(design.rejection_reason)}</p>
                    </div>
                ` : ''}
                
                <button type="button" data-design-id="${escapeHtml(design.id)}"
                    class="w-full rounded-lg border border-slate-200 bg-slate-800 py-2.5 font-semibold text-white transition hover:bg-slate-700">
                    <i class="fas fa-eye mr-2"></i>
                    ${design.status === 'pending' ? 'Review Design' : 'View Details'}
                </button>
            </div>
        </div>
    `;
}

// Render Leaderboard
function renderLeaderboard() {
    const container = document.getElementById('leaderboard-content');
    const sortedDesigns = [...allDesigns]
        .filter(d => d.status === 'approved')
        .sort((a, b) => (b.likes_count || 0) - (a.likes_count || 0));
    
    if (sortedDesigns.length === 0) {
        container.innerHTML = `
            <div class="text-center py-20">
                <div class="text-6xl mb-4">🏆</div>
                <h3 class="text-2xl font-bold text-white mb-2">No Designs Yet</h3>
                <p class="text-gray-400">Leaderboard will appear when designs are approved.</p>
            </div>
        `;
        return;
    }
    
    const top3 = sortedDesigns.slice(0, 3);
    const rest = sortedDesigns.slice(3);
    
    container.innerHTML = `
        <div class="mb-8">
            <h3 class="text-2xl font-bold text-black mb-6">🏆 Top 3 Most Loved</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                ${top3.map((design, index) => `
                    <div class="bg-gradient-to-br ${getMedalGradient(index)} p-6 rounded-2xl">
                        <div class="flex items-center gap-4 mb-4">
                            <div class="text-5xl">${getMedalEmoji(index)}</div>
                            <div class="text-white">
                                <h4 class="text-2xl font-bold">#${index + 1}</h4>
                                <p class="text-sm opacity-80">Rank</p>
                            </div>
                        </div>
                        <img src="${safeImageUrl(design.front_image_url)}" alt="${escapeHtml(design.title)}" class="w-full h-40 object-cover rounded-xl mb-4">
                        <h4 class="text-white font-bold text-lg mb-1">${escapeHtml(design.title)}</h4>
                        <p class="text-white/80 text-sm mb-3">${escapeHtml(design.designer?.brand_name || 'Unknown')}</p>
                        <div class="flex items-center gap-2 text-red-500">
                            <i class="fas fa-heart text-xl"></i>
                            <span class="text-2xl font-bold">${escapeHtml(design.likes_count || 0)}</span>
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
        
        ${rest.length > 0 ? `
            <div>
                <h3 class="text-2xl font-bold text-white mb-6">Other Rankings</h3>
                <div class="space-y-3">
                    ${rest.map((design, index) => `
                        <div class="bg-gray-800 border border-gray-700 rounded-xl p-4 flex items-center gap-4 hover:border-cyan-500 transition">
                            <div class="w-12 h-12 bg-gray-700 rounded-full flex items-center justify-center">
                                <span class="text-xl font-bold text-cyan-500">#${index + 4}</span>
                            </div>
                            <img src="${safeImageUrl(design.front_image_url)}" alt="${escapeHtml(design.title)}" class="w-16 h-16 object-cover rounded-lg">
                            <div class="flex-1">
                                <h4 class="text-white font-semibold">${escapeHtml(design.title)}</h4>
                                <p class="text-gray-400 text-sm">${escapeHtml(design.designer?.brand_name || 'Unknown')}</p>
                            </div>
                            <div class="text-right">
                                <div class="flex items-center gap-2 text-white">
                                    <i class="fas fa-heart text-red-500"></i>
                                    <span class="text-xl font-bold">${escapeHtml(design.likes_count || 0)}</span>
                                </div>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>
        ` : ''}
    `;
}

// Get Medal Emoji
function getMedalEmoji(index) {
    const medals = ['🥇', '🥈', '🥉'];
    return medals[index] || '';
}

// Get Medal Gradient
function getMedalGradient(index) {
    const gradients = [
        'from-yellow-600 to-yellow-400',
        'from-gray-400 to-gray-300',
        'from-orange-600 to-orange-400'
    ];
    return gradients[index] || 'from-gray-700 to-gray-600';
}

// Render Designers
function renderFeedback() {
    const container = document.getElementById('feedback-list');
    if (!allFeedback.length) {
        container.innerHTML = '<div class="empty-state"><span class="empty-state-icon"><i class="far fa-comment-dots"></i></span><h3>No feedback yet</h3><p>Customer ratings and comments on approved designs will appear here.</p></div>';
        return;
    }

    const sorted = [...allFeedback].sort((a, b) => {
        if (feedbackSort === 'highest') return Number(b.rating || 0) - Number(a.rating || 0);
        if (feedbackSort === 'lowest') return Number(a.rating || 0) - Number(b.rating || 0);
        return new Date(b.created_at) - new Date(a.created_at);
    });

    container.innerHTML = `
        <table class="admin-table feedback-table">
            <thead><tr><th>Rating</th><th>Reviewer</th><th>Feedback</th><th>Target design</th><th>Submitted</th></tr></thead>
            <tbody>${sorted.map((feedback) => {
        const rating = Number(feedback.rating);
        const hasRating = Number.isFinite(rating) && rating >= 1 && rating <= 5;
        const author = feedback.author?.full_name || feedback.author?.email || 'ClosetX customer';
        return `
            <tr data-searchable>
                <td>${hasRating ? `<span class="rating-value" aria-label="${rating} out of 5">${rating.toFixed(1)} <span>★</span></span>` : '<span class="text-gray-400">No rating</span>'}</td>
                <td><strong>${escapeHtml(author)}</strong></td>
                <td class="feedback-message">${escapeHtml(feedback.comment_text || 'Rating only; no written comment.')}</td>
                <td>${escapeHtml(feedback.design?.title || 'Design no longer available')}</td>
                <td>${escapeHtml(new Date(feedback.created_at).toLocaleDateString())}</td>
            </tr>
        `;
            }).join('')}</tbody>
        </table>
    `;
    applyCurrentSearch();
}

function renderDesigners() {
    const container = document.getElementById('designers-grid');
    const verifiedDesigners = allDesigners.filter((designer) => designer.application_status === 'approved' && designer.is_verified);
    
    if (verifiedDesigners.length === 0) {
        container.innerHTML = '<div class="empty-state"><span class="empty-state-icon"><i class="fas fa-users"></i></span><h3>No approved designers</h3><p>Accepted designer applications will be listed here.</p></div>';
        return;
    }
    
    container.innerHTML = `<table class="admin-table">
        <thead><tr><th>Designer</th><th>Location</th><th>Design requests</th><th>Approved assets</th><th>Joined</th></tr></thead>
        <tbody>${verifiedDesigners.map(designer => {
        const designCount = allDesigns.filter(d => d.designer_id === designer.user_id).length;
        const approvedCount = allDesigns.filter(d => d.designer_id === designer.user_id && d.status === 'approved').length;
        return `
            <tr data-searchable>
                <td><div class="table-identity"><div class="table-avatar">${designer.profile_image_url ? `<img src="${safeImageUrl(designer.profile_image_url)}" alt="">` : escapeHtml((designer.brand_name || 'UN').slice(0, 2).toUpperCase())}</div><div><strong>${escapeHtml(designer.brand_name || 'Unnamed designer')}</strong><small>${escapeHtml(designer.profile?.email || '')}</small></div></div></td>
                <td>${escapeHtml(designer.location || '—')}</td>
                <td>${designCount}</td><td>${approvedCount}</td><td>${escapeHtml(new Date(designer.created_at).toLocaleDateString())}</td>
            </tr>
        `;
        }).join('')}</tbody></table>`;
    applyCurrentSearch();
}

// Refresh Data
async function refreshData() {
    await loadDashboard();
    showSection(currentSection);
}

// Open Approval Modal
function openApprovalModal(design) {
    const modal = document.getElementById('approvalModal');
    const isPending = design.status === 'pending';
    modal.dataset.designId = design.id;
    
    modal.innerHTML = `
        <div class="p-6 border-b border-gray-700 flex justify-between items-center">
            <div>
                <h2 class="text-2xl font-bold text-white">Review Design</h2>
                <p class="text-gray-400 text-sm">Approve or reject this submission</p>
            </div>
            <button type="button" data-modal-close class="text-gray-400 hover:text-white transition">
                <i class="fas fa-times text-2xl"></i>
            </button>
        </div>
        
        <div class="p-6 max-h-[calc(90vh-100px)] overflow-y-auto">
            <!-- Images -->
            <div class="grid grid-cols-2 gap-4 mb-6">
                <div>
                    <img src="${safeImageUrl(design.front_image_url)}" alt="Front" class="w-full h-64 object-cover rounded-xl">
                    <p class="text-center text-gray-400 text-sm mt-2">Front</p>
                </div>
                <div>
                    <img src="${safeImageUrl(design.back_image_url)}" alt="Back" class="w-full h-64 object-cover rounded-xl">
                    <p class="text-center text-gray-400 text-sm mt-2">Back</p>
                </div>
            </div>
            
            <!-- Design Info -->
            <div class="bg-gray-900 rounded-xl p-5 mb-6 space-y-3">
                <div class="flex justify-between">
                    <span class="text-gray-400">Title:</span>
                    <span class="text-white font-semibold">${escapeHtml(design.title)}</span>
                </div>
                <div class="flex justify-between">
                    <span class="text-gray-400">Designer:</span>
                    <span class="text-white font-semibold">${escapeHtml(design.designer?.brand_name || 'Unknown')}</span>
                </div>
                <div class="flex justify-between">
                    <span class="text-gray-400">Price:</span>
                    <span class="text-cyan-500 font-bold">₱${escapeHtml(Number(design.price || 0).toFixed(2))}</span>
                </div>
                ${design.category ? `
                    <div class="flex justify-between">
                        <span class="text-gray-400">Category:</span>
                        <span class="text-white">${escapeHtml(design.category)}</span>
                    </div>
                ` : ''}
                ${design.description ? `
                    <div>
                        <span class="text-gray-400 block mb-1">Description:</span>
                        <span class="text-white">${escapeHtml(design.description)}</span>
                    </div>
                ` : ''}
                <div class="flex justify-between">
                    <span class="text-gray-400">Likes:</span>
                    <span class="text-white">❤️ ${escapeHtml(design.likes_count || 0)}</span>
                </div>
            </div>
            
            <!-- Designer Info -->
            <div class="bg-gray-900 rounded-xl p-5 mb-6">
                <h3 class="text-lg font-bold text-white mb-4">Designer Information</h3>
                <div class="flex items-center gap-4">
                    <div class="w-16 h-16 rounded-full bg-gray-700 flex items-center justify-center text-xl font-bold overflow-hidden">
                        ${design.designer?.profile_image_url 
                            ? `<img src="${safeImageUrl(design.designer.profile_image_url)}" alt="" class="w-full h-full object-cover">`
                            : escapeHtml((design.designer?.brand_name || 'UN').substring(0, 2).toUpperCase())
                        }
                    </div>
                    <div>
                        <h4 class="text-white font-semibold">${escapeHtml(design.designer?.brand_name || 'Unknown')}</h4>
                        ${design.designer?.location ? `<p class="text-gray-400 text-sm">📍 ${escapeHtml(design.designer.location)}</p>` : ''}
                        ${design.designer?.bio ? `<p class="text-gray-400 text-sm mt-1">${escapeHtml(design.designer.bio)}</p>` : ''}
                    </div>
                </div>
            </div>
            
            ${isPending ? `
                <!-- Approval Section -->
                <div class="bg-gray-900 rounded-xl p-5 mb-4">
                    <h3 class="text-lg font-bold text-white mb-4">✅ Approve Design</h3>
                    <div class="space-y-4">
                        <div>
                            <label class="block text-gray-300 text-sm font-medium mb-2">Snap Lens ID *</label>
                            <input
                                type="text"
                                id="lensId"
                                required
                                value="${escapeHtml(design.lens_id || '')}"
                                placeholder="Enter Snap Lens ID"
                                class="w-full bg-gray-700 border border-gray-600 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500"
                            >
                            <p class="text-gray-500 text-xs mt-1">Enter the Lens ID from Snap Lens Studio</p>
                        </div>
                        <div>
                            <label class="block text-gray-300 text-sm font-medium mb-2">Lens Group ID *</label>
                            <input
                                type="text"
                                id="lensGroupId"
                                required
                                value="${escapeHtml(design.lens_group_id || '')}"
                                placeholder="Enter Snap Lens Group ID"
                                class="w-full bg-gray-700 border border-gray-600 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500"
                            >
                            <p class="text-gray-500 text-xs mt-1">Use the Lens Group ID paired with this design.</p>
                        </div>
                    </div>
                </div>
                
                <!-- Rejection Section -->
                <div class="bg-gray-900 rounded-xl p-5 mb-6">
                    <h3 class="text-lg font-bold text-white mb-4">❌ Or Reject Design</h3>
                    <div>
                        <label class="block text-gray-300 text-sm font-medium mb-2">Rejection Reason *</label>
                        <textarea 
                            id="rejectionReason" 
                            rows="4"
                            placeholder="Explain why this design is being rejected..."
                            class="w-full bg-gray-700 border border-gray-600 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-red-500 resize-none"
                        ></textarea>
                    </div>
                </div>
            ` : ''}
            
            ${design.status === 'approved' ? `
                <div class="bg-cyan-500/10 border border-cyan-500/30 rounded-xl p-4 mb-6 flex items-center gap-3">
                    <i class="fas fa-check-circle text-2xl text-cyan-500"></i>
                    <div>
                        <strong class="text-cyan-500 block">Design Approved ✅</strong>
                        <p class="text-gray-300 text-sm">Lens ID: ${escapeHtml(design.lens_id || 'Not set')}</p>
                        <p class="text-gray-300 text-sm">Group ID: ${escapeHtml(design.lens_group_id || 'Not set')}</p>
                    </div>
                </div>
            ` : ''}
            
            ${design.status === 'rejected' && design.rejection_reason ? `
                <div class="bg-red-500/10 border border-red-500/30 rounded-xl p-4 mb-6 flex items-center gap-3">
                    <i class="fas fa-times-circle text-2xl text-red-500"></i>
                    <div>
                        <strong class="text-red-500 block">Design Rejected ❌</strong>
                        <p class="text-gray-300 text-sm">${escapeHtml(design.rejection_reason)}</p>
                    </div>
                </div>
            ` : ''}
            
            <div id="modalError" class="hidden mb-4 bg-red-500/10 border border-red-500/30 rounded-xl p-4 flex items-center gap-3">
                <span class="text-xl">⚠️</span>
                <span id="modalErrorMessage" class="text-red-500 text-sm"></span>
            </div>
        </div>
        
        <div class="p-6 border-t border-gray-700 flex gap-3">
            ${isPending ? `
                <button type="button" data-action="reject"
                    class="flex-1 py-3 bg-red-500 hover:bg-red-600 text-white font-semibold rounded-xl transition flex items-center justify-center gap-2">
                    <i class="fas fa-times-circle"></i>
                    <span>Reject</span>
                </button>
                <button type="button" data-action="approve"
                    class="flex-1 py-3 bg-cyan-500 hover:bg-cyan-600 text-white font-semibold rounded-xl transition flex items-center justify-center gap-2">
                    <i class="fas fa-check-circle"></i>
                    <span>Approve</span>
                </button>
            ` : `
                <button type="button" data-modal-close
                    class="flex-1 py-3 bg-gray-700 hover:bg-gray-600 text-white font-semibold rounded-xl transition">
                    Close
                </button>
            `}
        </div>
    `;
    
    modal.classList.remove('hidden');
    modal.querySelector('[data-modal-close]')?.addEventListener('click', closeApprovalModal);
    modal.querySelector('[data-action="approve"]')?.addEventListener('click', () => approveDesign(design.id));
    modal.querySelector('[data-action="reject"]')?.addEventListener('click', () => rejectDesign(design.id));
}

// Close Approval Modal
function closeApprovalModal() {
    document.getElementById('approvalModal').classList.add('hidden');
}

// Approve Design
async function approveDesign(designId) {
    const lensId = document.getElementById('lensId').value.trim();
    const lensGroupId = document.getElementById('lensGroupId').value.trim();
    const errorDiv = document.getElementById('modalError');
    const errorMessage = document.getElementById('modalErrorMessage');
    
    if (!lensId || !lensGroupId) {
        errorMessage.textContent = 'Please enter both the Lens ID and Lens Group ID.';
        errorDiv.classList.remove('hidden');
        return;
    }
    
    try {
        const { data, error } = await closetxSupabase
            .from('designs')
            .update({
                status: 'approved',
                lens_id: lensId,
                lens_group_id: lensGroupId,
                rejection_reason: null,
                updated_at: new Date().toISOString()
            })
            .eq('id', designId)
            .eq('status', 'pending')
            .select('id');
        
        if (error) throw error;
        if (!data?.length) throw new Error('This design is no longer pending or could not be updated.');
        
        closeApprovalModal();
        await refreshData();
        
    } catch (error) {
        errorMessage.textContent = error.message;
        errorDiv.classList.remove('hidden');
    }
}

// Reject Design
async function rejectDesign(designId) {
    const rejectionReason = document.getElementById('rejectionReason').value.trim();
    const errorDiv = document.getElementById('modalError');
    const errorMessage = document.getElementById('modalErrorMessage');
    
    if (!rejectionReason) {
        errorMessage.textContent = 'Please provide a rejection reason';
        errorDiv.classList.remove('hidden');
        return;
    }
    
    try {
        const { data, error } = await closetxSupabase
            .from('designs')
            .update({
                status: 'rejected',
                rejection_reason: rejectionReason,
                updated_at: new Date().toISOString()
            })
            .eq('id', designId)
            .eq('status', 'pending')
            .select('id');
        
        if (error) throw error;
        if (!data?.length) throw new Error('This design is no longer pending or could not be updated.');
        
        closeApprovalModal();
        await refreshData();
        
    } catch (error) {
        errorMessage.textContent = error.message;
        errorDiv.classList.remove('hidden');
    }
}