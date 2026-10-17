let allDesigns = [];
let allDesigners = [];
let allFeedback = [];
let currentSection = 'overview';
let designFilter = 'pending';
let designDesignerFilter = 'all';
let applicationFilter = 'pending';
let feedbackSort = 'newest';
let notificationSort = 'all';

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

function formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? '—' : date.toLocaleDateString();
}

function showDashboardError(message) {
    let banner = document.getElementById('dashboard-error');
    if (!banner) {
        banner = document.createElement('div');
        banner.id = 'dashboard-error';
        banner.setAttribute('role', 'alert');
        banner.className = 'mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800';
        document.querySelector('main header')?.insertAdjacentElement('afterend', banner);
    }
    banner.textContent = message;
    banner.classList.remove('hidden');
}

function clearDashboardError() {
    document.getElementById('dashboard-error')?.classList.add('hidden');
}

function updateAdminIdentity(session) {
    const email = session?.user?.email || 'Administrator';
    const initials = email.split('@')[0].split(/[._-]/).filter(Boolean).slice(0, 2)
        .map((part) => part[0]).join('').toUpperCase() || 'AD';
    for (const id of ['admin-name', 'topbar-admin-name']) {
        const element = document.getElementById(id);
        if (element) element.textContent = email;
    }
    for (const id of ['admin-avatar', 'topbar-avatar']) {
        const element = document.getElementById(id);
        if (element) element.textContent = initials;
    }
}

async function checkAuth() {
    try {
        await closetxSupabaseReady;
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
        showDashboardError(`Could not connect or verify admin access: ${error.message}`);
        return false;
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    bindDashboardControls();
    if (await checkAuth()) await loadDashboard();
});

function bindDashboardControls() {
    document.getElementById('global-search')?.addEventListener('input', applyCurrentSearch);
    document.getElementById('notification-button')?.addEventListener('click', () => {
        const panel = document.getElementById('notification-panel');
        const isHidden = panel?.classList.contains('hidden');
        document.querySelectorAll('.notification-panel').forEach((box) => box.classList.add('hidden'));
        if (isHidden) {
            panel?.classList.remove('hidden');
            renderNotifications();
        }
    });
    document.querySelectorAll('[data-notification-sort]').forEach((button) => {
        button.addEventListener('click', () => {
            const sort = button.dataset.notificationSort;
            if (sort) {
                notificationSort = sort;
                document.querySelectorAll('.notification-sort-tab').forEach((tab) => tab.classList.toggle('active', tab.dataset.notificationSort === sort));
                document.querySelector('.notification-sort-button')?.setAttribute('data-notification-sort', sort);
                renderNotifications();
            }
        });
    });
    document.addEventListener('click', (event) => {
        const panel = document.getElementById('notification-panel');
        if (!panel) return;
        const clickedWithin = panel.contains(event.target) || document.getElementById('notification-button')?.contains(event.target);
        if (!clickedWithin) panel.classList.add('hidden');
    });
    document.querySelectorAll('[data-design-filter]').forEach((button) => {
        button.addEventListener('click', () => {
            designFilter = button.dataset.designFilter;
            document.querySelectorAll('[data-design-filter]').forEach((tab) => tab.classList.toggle('active', tab === button));
            renderPendingDesigns();
        });
    });
    document.getElementById('design-designer-filter')?.addEventListener('change', (event) => {
        designDesignerFilter = event.target.value;
        renderPendingDesigns();
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
    for (const modalId of ['approvalModal', 'applicationModal']) {
        document.getElementById(modalId)?.addEventListener('click', (event) => {
            if (event.target.id === modalId) closeModal(modalId);
        });
    }
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            closeModal('approvalModal');
            closeModal('applicationModal');
        }
        if (event.key === '/' && !['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) {
            event.preventDefault();
            document.getElementById('global-search')?.focus();
        }
    });
}

function applyCurrentSearch() {
    const query = document.getElementById('global-search')?.value.trim().toLowerCase() || '';
    document.getElementById(`${currentSection}-section`)?.querySelectorAll('[data-searchable]').forEach((row) => {
        row.classList.toggle('hidden', !row.textContent.toLowerCase().includes(query));
    });
}

async function loadDashboard() {
    clearDashboardError();
    try {
        await Promise.all([loadDesigns(), loadDesigners(), loadFeedback()]);
        renderStats();
        renderRecentActivity();
        renderCharts();
        showSection(currentSection);
    } catch (error) {
        console.error('Could not load admin dashboard:', error);
        showDashboardError(`Could not load dashboard data: ${error.message}`);
    }
}

async function loadDesigns() {
    const { data, error } = await closetxSupabase
        .from('designs')
        .select('id, designer_id, brand_id, title, description, front_image_url, back_image_url, thumbnail_url, price, category, shirt_color, is_published, review_status, rejection_reason, created_at, brands(name, bio, location, logo_url)')
        .order('created_at', { ascending: false });
    if (error) throw new Error(`Could not load designs: ${error.message}`);

    allDesigns = (data || []).map((design) => ({
        ...design,
        status: design.review_status,
        designer: allDesigners.find((designer) => designer.id === design.designer_id)
            || { brand_name: design.brands?.name || 'ClosetX Designer' },
    }));
}

async function loadDesigners() {
    const { data: profiles, error: profileError } = await closetxSupabase
        .from('profiles')
        .select('id, email, full_name, role, designer_status, designer_rejection_reason, created_at')
        .eq('role', 'designer')
        .order('created_at', { ascending: false });
    if (profileError) throw new Error(`Could not load designer applications: ${profileError.message}`);

    const { data: brands, error: brandError } = await closetxSupabase
        .from('brands')
        .select('id, owner_id, name, bio, location, logo_url, created_at');
    if (brandError) throw new Error(`Could not load designer brands: ${brandError.message}`);

    const brandsByOwner = new Map((brands || []).map((brand) => [brand.owner_id, brand]));
    allDesigners = (profiles || []).map((profile) => {
        const brand = brandsByOwner.get(profile.id);
        return {
            ...profile,
            user_id: profile.id,
            application_status: profile.designer_status,
            application_rejection_reason: profile.designer_rejection_reason,
            brand_name: brand?.name || '',
            location: brand?.location || '',
            bio: brand?.bio || '',
            profile_image_url: brand?.logo_url || '',
            brand_created_at: brand?.created_at || null,
        };
    });

    const designersById = new Map(allDesigners.map((designer) => [designer.id, designer]));
    allDesigns = allDesigns.map((design) => ({
        ...design,
        designer: designersById.get(design.designer_id)
            || { brand_name: design.brands?.name || 'ClosetX Designer' },
    }));
}

async function loadFeedback() {
    const { data, error } = await closetxSupabase
        .from('feedback')
        .select('id, user_id, author_name, author_email, message, rating, created_at')
        .order('created_at', { ascending: false });
    if (error) throw new Error(`Could not load customer feedback: ${error.message}`);
    allFeedback = data || [];
}

function renderStats() {
    const stats = {
        pending: allDesigns.filter((design) => design.status === 'pending').length,
        approved: allDesigns.filter((design) => design.status === 'approved').length,
        rejected: allDesigns.filter((design) => design.status === 'rejected').length,
        applications: allDesigners.filter((designer) => designer.application_status === 'pending').length,
        designers: allDesigners.filter((designer) => designer.application_status === 'approved').length,
        feedback: allFeedback.length,
    };
    document.getElementById('stats-cards').innerHTML = `
        <button type="button" onclick="showSection('applications')" class="metric-card">
            <span class="metric-icon metric-amber"><i class="fas fa-id-card"></i></span>
            <span><strong>${stats.applications}</strong><small>Pending applications</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('pending')" class="metric-card">
            <span class="metric-icon metric-slate"><i class="fas fa-images"></i></span>
            <span><strong>${stats.pending}</strong><small>Designs awaiting review</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('designers')" class="metric-card">
            <span class="metric-icon metric-emerald"><i class="fas fa-users"></i></span>
            <span><strong>${stats.designers}</strong><small>Accepted designers</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
        <button type="button" onclick="showSection('feedback')" class="metric-card">
            <span class="metric-icon metric-slate"><i class="fas fa-comment-dots"></i></span>
            <span><strong>${stats.feedback}</strong><small>Customer feedback</small></span>
            <i class="fas fa-arrow-right metric-arrow"></i>
        </button>
    `;
    document.getElementById('pending-badge').textContent = stats.pending;
    document.getElementById('applications-badge').textContent = stats.applications;
    document.getElementById('designers-badge').textContent = stats.designers;
    document.getElementById('feedback-badge').textContent = stats.feedback;
    const totalNotifications = stats.applications + stats.pending;
    document.getElementById('notification-count').textContent = totalNotifications;
    document.getElementById('notification-button').setAttribute(
        'aria-label',
        `${stats.applications} pending designer applications and ${stats.pending} pending designs`,
    );

    const totalDesigns = allDesigns.length;
    const totalApprovedDesigns = allDesigns.filter((design) => design.status === 'approved').length;
    const totalRejectedDesigns = allDesigns.filter((design) => design.status === 'rejected').length;
    const totalApplicants = allDesigners.length;
    const totalApprovedApplicants = allDesigners.filter((designer) => designer.application_status === 'approved').length;
    const totalRejectedApplicants = allDesigners.filter((designer) => designer.application_status === 'rejected').length;

    document.getElementById('pending-filter-count').textContent = stats.pending;
    document.getElementById('design-all-filter-count').textContent = totalDesigns;
    document.getElementById('design-approved-filter-count').textContent = totalApprovedDesigns;
    document.getElementById('design-rejected-filter-count').textContent = totalRejectedDesigns;
    document.getElementById('application-filter-count').textContent = stats.applications;
    document.getElementById('application-all-filter-count').textContent = totalApplicants;
    document.getElementById('application-approved-filter-count').textContent = totalApprovedApplicants;
    document.getElementById('application-rejected-filter-count').textContent = totalRejectedApplicants;
    renderNotifications();
}

function getNotificationItems() {
    const pendingApplications = allDesigners
        .filter((designer) => designer.application_status === 'pending')
        .map((designer) => ({
            id: designer.id,
            type: 'application',
            title: designer.full_name || 'Designer applicant',
            subtitle: `${designer.brand_name || 'Brand pending'} • ${designer.email}`,
            created_at: designer.created_at,
            section: 'applications',
        }));

    const pendingDesigns = allDesigns
        .filter((design) => design.status === 'pending')
        .map((design) => ({
            id: design.id,
            type: 'design',
            title: design.title || 'New design',
            subtitle: `${design.designer?.brand_name || 'Designer'} • ${design.category || 'T-Shirts'}`,
            created_at: design.created_at,
            section: 'pending',
        }));

    const allItems = [...pendingApplications, ...pendingDesigns]
        .sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));

    if (notificationSort === 'application') return allItems.filter((item) => item.type === 'application');
    if (notificationSort === 'design') return allItems.filter((item) => item.type === 'design');
    return allItems;
}

function renderNotifications() {
    const list = document.getElementById('notification-list');
    if (!list) return;

    const items = getNotificationItems();
    if (!items.length) {
        list.innerHTML = '<div class="notification-empty">No pending designer applications or design approvals.</div>';
        return;
    }

    list.innerHTML = items.map((item) => `
        <button type="button" class="notification-item" data-notify-section="${item.section}" data-notify-id="${escapeHtml(item.id)}">
            <span class="notification-bullet ${item.type}">${item.type === 'application' ? 'A' : 'D'}</span>
            <span class="notification-content">
                <span class="notification-title">${escapeHtml(item.title)}</span>
                <span class="notification-subtitle">${escapeHtml(item.subtitle)}</span>
            </span>
            <span class="notification-time">${escapeHtml(formatDate(item.created_at))}</span>
        </button>
    `).join('');

    list.querySelectorAll('.notification-item').forEach((button) => {
        button.addEventListener('click', () => {
            const section = button.dataset.notifySection;
            const id = button.dataset.notifyId;
            if (section === 'applications') {
                applicationFilter = 'pending';
                showSection('applications');
                openApplication(id);
            } else {
                designFilter = 'pending';
                showSection('pending');
                openDesignReview(id);
            }
            document.getElementById('notification-panel')?.classList.add('hidden');
        });
    });
}

function renderRecentActivity() {
    const recent = allDesigns.slice(0, 5);
    document.getElementById('recent-activity').innerHTML = recent.length ? `
        <table class="admin-table">
            <thead><tr><th>Design</th><th>Designer</th><th>Submitted</th><th>Status</th></tr></thead>
            <tbody>${recent.map((design) => `<tr data-searchable>
                <td><div class="table-identity"><img src="${safeImageUrl(design.thumbnail_url || design.front_image_url)}" alt="" class="table-thumbnail"><div><strong>${escapeHtml(design.title)}</strong><small>${escapeHtml(design.category || 'T-Shirts')}</small></div></div></td>
                <td>${escapeHtml(design.designer?.brand_name)}</td>
                <td>${escapeHtml(formatDate(design.created_at))}</td>
                <td>${statusPill(design.status)}</td>
            </tr>`).join('')}</tbody>
        </table>` : '<div class="empty-state"><h3>No design submissions yet</h3><p>New designer uploads will appear here.</p></div>';
}

function statusPill(status) {
    const label = status === 'approved' ? 'Accepted' : status === 'rejected' ? 'Denied' : 'Pending';
    return `<span class="status-pill status-${escapeHtml(status)}">${label}</span>`;
}

function showSection(section) {
    currentSection = section;
    document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
    document.getElementById(`nav-${section}`)?.classList.add('active');
    document.querySelectorAll('.section').forEach((item) => item.classList.add('hidden'));
    const titles = {
        overview: ['Overview', 'Dashboard analytics and insights'],
        pending: ['Design approvals', 'Review and approve designer uploads'],
        applications: ['Designer applications', 'Accept or deny requests to join ClosetX as a designer'],
        designers: ['Designers', 'Accepted designer accounts'],
        feedback: ['Customer feedback', 'Feedback submitted from the ClosetX app'],
    };
    if (!titles[section]) return;
    document.getElementById('page-title').textContent = titles[section][0];
    document.getElementById('page-subtitle').textContent = titles[section][1];
    document.getElementById(`${section}-section`)?.classList.remove('hidden');
    if (section === 'pending') renderPendingDesigns();
    if (section === 'applications') renderApplications();
    if (section === 'designers') renderDesigners();
    if (section === 'feedback') renderFeedback();
    applyCurrentSearch();
}

function renderPendingDesigns() {
    const designerFilter = document.getElementById('design-designer-filter');
    const designersWithDesigns = new Map();
    allDesigns.forEach((design) => {
        const brandName = design.designer?.brand_name || design.brands?.name || 'ClosetX Designer';
        const designerName = design.designer?.full_name || design.designer?.email;
        const label = designerName && designerName !== brandName
            ? `${brandName} — ${designerName}`
            : brandName;
        designersWithDesigns.set(design.designer_id, label);
    });
    if (designerFilter) {
        const availableDesigners = [...designersWithDesigns.entries()]
            .sort((a, b) => a[1].localeCompare(b[1]));
        designerFilter.innerHTML = '<option value="all">All designers</option>' + availableDesigners
            .map(([id, name]) => `<option value="${escapeHtml(id)}">${escapeHtml(name)}</option>`)
            .join('');
        if (designDesignerFilter !== 'all' && designersWithDesigns.has(designDesignerFilter)) {
            designerFilter.value = designDesignerFilter;
        } else {
            designDesignerFilter = 'all';
            designerFilter.value = 'all';
        }
    }
    const designs = (designFilter === 'all'
        ? allDesigns
        : allDesigns.filter((design) => design.status === designFilter))
        .filter((design) => designDesignerFilter === 'all' || design.designer_id === designDesignerFilter);
    document.getElementById('asset-results-count').textContent = `${designs.length} ${designs.length === 1 ? 'design' : 'designs'}`;
    document.getElementById('pending-designs').innerHTML = designs.length ? `
        <table class="admin-table">
            <thead><tr><th>Design</th><th>Designer</th><th>Category</th><th>Submitted</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>${designs.map((design) => `<tr data-searchable>
                <td><div class="table-identity"><img src="${safeImageUrl(design.thumbnail_url || design.front_image_url)}" alt="" class="table-thumbnail"><div><strong>${escapeHtml(design.title)}</strong><small>₱${escapeHtml(Number(design.price || 0).toLocaleString())}</small></div></div></td>
                <td>${escapeHtml(design.designer?.brand_name || 'ClosetX Designer')}</td>
                <td>${escapeHtml(design.category || 'T-Shirts')}</td>
                <td>${escapeHtml(formatDate(design.created_at))}</td>
                <td>${statusPill(design.status)}</td>
                <td><div class="row-actions">
                    <button type="button" data-design-id="${escapeHtml(design.id)}" class="row-action">${design.status === 'pending' ? 'Review' : 'Details'} <i class="fas fa-arrow-right"></i></button>
                    <button type="button" data-remove-design="${escapeHtml(design.id)}" class="row-action row-action-danger">Remove</button>
                </div></td>
            </tr>`).join('')}</tbody>
        </table>` : `<div class="empty-state"><span class="empty-state-icon"><i class="far fa-images"></i></span><h3>No matching designs</h3><p>New uploads appear here when designers submit them.</p></div>`;
    document.getElementById('pending-designs').querySelectorAll('[data-design-id]').forEach((button) => {
        button.addEventListener('click', () => openDesignReview(button.dataset.designId));
    });
    document.getElementById('pending-designs').querySelectorAll('[data-remove-design]').forEach((button) => {
        button.addEventListener('click', () => removeDesign(button.dataset.removeDesign, button));
    });
    applyCurrentSearch();
}

function renderApplications() {
    const applications = allDesigners.filter((designer) => applicationFilter === 'all'
        || designer.application_status === applicationFilter);
    const container = document.getElementById('applications-list');
    container.innerHTML = applications.length ? `
        <table class="admin-table">
            <thead><tr><th>Applicant</th><th>Email</th><th>Brand</th><th>Applied</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>${applications.map((designer) => {
                const name = designer.full_name || 'Designer applicant';
                return `<tr data-searchable>
                    <td><div class="table-identity"><div class="table-avatar">${escapeHtml(name.slice(0, 2).toUpperCase())}</div><div><strong>${escapeHtml(name)}</strong><small>${escapeHtml(designer.id)}</small></div></div></td>
                    <td>${escapeHtml(designer.email)}</td>
                    <td>${escapeHtml(designer.brand_name || 'Not created yet')}</td>
                    <td>${escapeHtml(formatDate(designer.created_at))}</td>
                    <td>${statusPill(designer.application_status)}</td>
                    <td><div class="row-actions">
                        <button type="button" data-application-id="${escapeHtml(designer.id)}" class="row-action">Details</button>
                        ${designer.application_status === 'pending' ? `<button type="button" data-review-application="${escapeHtml(designer.id)}" class="row-action row-action-primary">Review</button>` : ''}
                    </div></td>
                </tr>`;
            }).join('')}</tbody>
        </table>` : '<div class="empty-state"><span class="empty-state-icon"><i class="far fa-id-card"></i></span><h3>No matching applications</h3><p>Designer sign-ups will appear here for review.</p></div>';
    container.querySelectorAll('[data-application-id], [data-review-application]').forEach((button) => {
        button.addEventListener('click', () => openApplication(button.dataset.applicationId || button.dataset.reviewApplication));
    });
    applyCurrentSearch();
}

function openApplication(id) {
    const designer = allDesigners.find((item) => item.id === id);
    if (!designer) return;
    const modal = document.getElementById('applicationModal');
    const rejected = designer.application_status === 'rejected';
    modal.innerHTML = `<div class="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl">
        <div class="flex items-center justify-between border-b border-gray-200 p-5">
            <div><h2 class="text-xl font-bold text-gray-900">Designer application</h2><p class="text-sm text-gray-500">${escapeHtml(designer.full_name || 'Applicant')}</p></div>
            <button type="button" data-close-modal class="px-3 py-2 text-gray-500" aria-label="Close">✕</button>
        </div>
        <div class="space-y-4 p-5">
            <p><strong>Email:</strong> ${escapeHtml(designer.email)}</p>
            <p><strong>Account created:</strong> ${escapeHtml(formatDate(designer.created_at))}</p>
            <p><strong>Current status:</strong> ${escapeHtml(designer.application_status)}</p>
            ${designer.brand_name ? `<div class="rounded-xl bg-gray-50 p-4"><h3 class="font-semibold">Brand: ${escapeHtml(designer.brand_name)}</h3><p>${escapeHtml(designer.bio || 'No brand description.')}</p><p>${escapeHtml(designer.location || '')}</p></div>` : '<p class="text-gray-500">The applicant has not created a brand yet.</p>'}
            ${designer.application_rejection_reason ? `<div class="rounded-xl bg-red-50 p-4 text-sm text-red-800"><strong>Previous decision:</strong> ${escapeHtml(designer.application_rejection_reason)}</div>` : ''}
            ${designer.application_status === 'pending' ? `<label class="block text-sm font-medium">Denial reason (required if denying)<textarea id="application-reason" rows="3" class="mt-2 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3"></textarea></label><p id="application-error" class="hidden text-sm text-red-700"></p>` : ''}
        </div>
        <div class="flex gap-3 border-t border-gray-200 p-5">
            ${designer.application_status === 'pending' ? `<button type="button" data-deny-application class="flex-1 rounded-xl bg-red-500 px-4 py-3 font-semibold text-white">Deny</button><button type="button" data-accept-application class="flex-1 rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white">Accept</button>` : '<button type="button" data-close-modal class="w-full rounded-xl bg-gray-100 px-4 py-3">Close</button>'}
        </div>
    </div>`;
    modal.classList.remove('hidden');
    modal.querySelectorAll('[data-close-modal]').forEach((button) => button.addEventListener('click', () => closeModal('applicationModal')));
    modal.querySelector('[data-accept-application]')?.addEventListener('click', () => reviewApplication(id, 'approved'));
    modal.querySelector('[data-deny-application]')?.addEventListener('click', () => reviewApplication(id, 'rejected'));
}

async function reviewApplication(id, status) {
    const reason = document.getElementById('application-reason')?.value.trim() || '';
    const errorElement = document.getElementById('application-error');
    if (status === 'rejected' && !reason) {
        errorElement.textContent = 'Add a reason so the applicant knows why the request was denied.';
        errorElement.classList.remove('hidden');
        return;
    }
    try {
        const { data, error } = await closetxSupabase.from('profiles')
            .update({
                designer_status: status,
                designer_rejection_reason: status === 'rejected' ? reason : null,
                designer_reviewed_at: new Date().toISOString(),
            })
            .eq('id', id)
            .eq('designer_status', 'pending')
            .select('id');
        if (error) throw error;
        if (!data?.length) throw new Error('This application has already been reviewed.');
        closeModal('applicationModal');
        await refreshData();
    } catch (error) {
        console.error('Could not review designer application:', error);
        if (errorElement) {
            errorElement.textContent = error.message;
            errorElement.classList.remove('hidden');
        } else showDashboardError(`Could not save the application decision: ${error.message}`);
    }
}

function openDesignReview(id) {
    const design = allDesigns.find((item) => item.id === id);
    if (!design) return;
    const isPending = design.status === 'pending';
    const modal = document.getElementById('approvalModal');
    modal.innerHTML = `<div class="bg-white rounded-2xl max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-2xl">
        <div class="flex items-center justify-between border-b border-gray-200 p-5">
            <div><h2 class="text-xl font-bold text-gray-900">${escapeHtml(design.title)}</h2><p class="text-sm text-gray-500">by ${escapeHtml(design.designer?.brand_name)}</p></div>
            <button type="button" data-close-modal class="px-3 py-2 text-gray-500" aria-label="Close">✕</button>
        </div>
        <div class="p-5">
            <div class="grid grid-cols-2 gap-3"><img src="${safeImageUrl(design.front_image_url)}" alt="Front artwork" class="h-64 w-full rounded-xl object-contain bg-gray-50"><img src="${safeImageUrl(design.back_image_url)}" alt="Back artwork" class="h-64 w-full rounded-xl object-contain bg-gray-50"></div>
            <div class="mt-4 grid grid-cols-2 gap-3 text-sm"><p><strong>Price:</strong> ₱${escapeHtml(Number(design.price || 0).toLocaleString())}</p><p><strong>Category:</strong> ${escapeHtml(design.category || 'T-Shirts')}</p><p><strong>Colour:</strong> ${escapeHtml(design.shirt_color || '')}</p><p><strong>Submitted:</strong> ${escapeHtml(formatDate(design.created_at))}</p></div>
            <p class="mt-4 whitespace-pre-wrap text-sm">${escapeHtml(design.description || 'No description provided.')}</p>
            ${design.rejection_reason ? `<p class="mt-4 rounded-xl bg-red-50 p-4 text-sm text-red-800"><strong>Denial reason:</strong> ${escapeHtml(design.rejection_reason)}</p>` : ''}
            ${isPending ? `<label class="mt-5 block text-sm font-medium">Denial reason (required if denying)<textarea id="design-reason" rows="3" class="mt-2 w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3"></textarea></label><p id="design-error" class="hidden mt-3 text-sm text-red-700"></p>` : ''}
        </div>
        <div class="flex gap-3 border-t border-gray-200 p-5">
            ${isPending ? `<button type="button" data-deny-design class="flex-1 rounded-xl bg-red-500 px-4 py-3 font-semibold text-white">Deny design</button><button type="button" data-accept-design class="flex-1 rounded-xl bg-slate-900 px-4 py-3 font-semibold text-white">Accept and publish</button>` : '<button type="button" data-close-modal class="w-full rounded-xl bg-gray-100 px-4 py-3">Close</button>'}
        </div>
    </div>`;
    modal.classList.remove('hidden');
    modal.querySelectorAll('[data-close-modal]').forEach((button) => button.addEventListener('click', () => closeModal('approvalModal')));
    modal.querySelector('[data-accept-design]')?.addEventListener('click', () => reviewDesign(id, 'approved'));
    modal.querySelector('[data-deny-design]')?.addEventListener('click', () => reviewDesign(id, 'rejected'));
}

async function reviewDesign(id, status) {
    const reason = document.getElementById('design-reason')?.value.trim() || '';
    const errorElement = document.getElementById('design-error');
    if (status === 'rejected' && !reason) {
        errorElement.textContent = 'Add a reason so the designer knows what to change.';
        errorElement.classList.remove('hidden');
        return;
    }
    try {
        const { data, error } = await closetxSupabase.from('designs')
            .update({
                review_status: status,
                rejection_reason: status === 'rejected' ? reason : null,
                reviewed_at: new Date().toISOString(),
                is_published: status === 'approved',
            })
            .eq('id', id)
            .eq('review_status', 'pending')
            .select('id');
        if (error) throw error;
        if (!data?.length) throw new Error('This design has already been reviewed.');
        closeModal('approvalModal');
        await refreshData();
    } catch (error) {
        console.error('Could not review design:', error);
        if (errorElement) {
            errorElement.textContent = error.message;
            errorElement.classList.remove('hidden');
        } else showDashboardError(`Could not save the design decision: ${error.message}`);
    }
}

async function removeDesign(id, button) {
    const design = allDesigns.find((item) => item.id === id);
    if (!design) return;
    if (!window.confirm(`Permanently remove "${design.title}"? Its uploaded images will also be deleted. This cannot be undone.`)) return;

    button.disabled = true;
    button.textContent = 'Removing...';
    try {
        const { data, error } = await closetxSupabase.functions.invoke('admin-remove-design', {
            body: { designId: id },
        });
        if (error) throw error;
        await refreshData();
        if (data?.warning) {
            const refreshError = document.getElementById('dashboard-error')?.textContent;
            showDashboardError([
                refreshError,
                `The design was removed, but its uploaded images could not all be cleaned up: ${data.warning}`,
            ].filter(Boolean).join(' '));
        }
    } catch (error) {
        console.error('Could not remove design:', error);
        showDashboardError(`Could not remove "${design.title}": ${error.message}`);
        button.disabled = false;
        button.textContent = 'Remove';
    }
}

function renderDesigners() {
    const designers = allDesigners.filter((designer) => designer.application_status === 'approved');
    document.getElementById('designers-grid').innerHTML = designers.length ? `
        <table class="admin-table">
            <thead><tr><th>Designer</th><th>Email</th><th>Brand</th><th>Location</th><th>Joined</th><th>Actions</th></tr></thead>
            <tbody>${designers.map((designer) => `<tr data-searchable>
                <td><strong>${escapeHtml(designer.full_name || 'Designer')}</strong></td><td>${escapeHtml(designer.email)}</td>
                <td>${escapeHtml(designer.brand_name || 'Not created yet')}</td><td>${escapeHtml(designer.location || '—')}</td>
                <td>${escapeHtml(formatDate(designer.created_at))}</td>
                <td><button type="button" data-remove-designer="${escapeHtml(designer.id)}" class="row-action row-action-danger">Remove account</button></td>
            </tr>`).join('')}</tbody>
        </table>` : '<div class="empty-state"><h3>No accepted designers yet</h3><p>Accepted designer accounts will appear here.</p></div>';
    document.getElementById('designers-grid').querySelectorAll('[data-remove-designer]').forEach((button) => {
        button.addEventListener('click', () => removeDesigner(button.dataset.removeDesigner, button));
    });
    applyCurrentSearch();
}

async function removeDesigner(id, button) {
    const designer = allDesigners.find((item) => item.id === id);
    if (!designer) return;

    const name = designer.full_name || designer.email || 'this designer';
    if (!window.confirm(
        `Permanently remove ${name} (${designer.email})? Their brand, designs, and uploaded images will also be deleted. This cannot be undone.`,
    )) return;

    button.disabled = true;
    button.textContent = 'Removing...';
    try {
        const { error } = await closetxSupabase.functions.invoke('admin-remove-designer', {
            body: { designerId: id },
        });
        if (error) throw error;
        allDesigners = allDesigners.filter((item) => item.id !== id);
        allDesigns = allDesigns.filter((item) => item.designer_id !== id);
        await refreshData();
    } catch (error) {
        console.error('Could not remove designer account:', error);
        showDashboardError(`Could not remove ${name}'s account: ${error.message}`);
        button.disabled = false;
        button.textContent = 'Remove account';
    }
}

function renderFeedback() {
    const feedback = [...allFeedback].sort((a, b) => {
        if (feedbackSort === 'highest') return (b.rating || 0) - (a.rating || 0);
        if (feedbackSort === 'lowest') return (a.rating || 0) - (b.rating || 0);
        return new Date(b.created_at) - new Date(a.created_at);
    });
    document.getElementById('feedback-list').innerHTML = feedback.length ? `
        <div class="space-y-3">${feedback.map((item) => `<article data-searchable class="rounded-xl border border-gray-200 bg-white p-5">
            <div class="flex flex-wrap items-center justify-between gap-2"><strong>${escapeHtml(item.author_name || 'ClosetX shopper')}</strong><span class="text-sm text-gray-500">${escapeHtml(formatDate(item.created_at))}</span></div>
            ${item.author_email ? `<p class="mt-1 text-sm text-gray-500">${escapeHtml(item.author_email)}</p>` : ''}
            ${item.rating ? `<p class="mt-2 text-amber-600" aria-label="${escapeHtml(item.rating)} out of 5 stars">${'★'.repeat(item.rating)}${'☆'.repeat(5 - item.rating)}</p>` : ''}
            <p class="mt-3 whitespace-pre-wrap text-sm leading-6 text-gray-700">${escapeHtml(item.message)}</p>
        </article>`).join('')}</div>` : '<div class="empty-state"><span class="empty-state-icon"><i class="far fa-comment-dots"></i></span><h3>No feedback yet</h3><p>Feedback submitted from the app will appear here.</p></div>';
}

function closeModal(id) {
    document.getElementById(id)?.classList.add('hidden');
}

async function refreshData() {
    const button = document.querySelector('.refresh-button');
    if (button) button.disabled = true;
    try {
        await loadDashboard();
    } finally {
        if (button) button.disabled = false;
    }
}
