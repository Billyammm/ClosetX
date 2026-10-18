const recoveryStorageKey = 'closetx_password_recovery_pending';
const recoveryRedirectUrl = 'https://admin-dashboard-one-alpha-13.vercel.app/login.html';
let isRecoveryFlow =
    new URLSearchParams(window.location.hash.slice(1)).get('type') === 'recovery' ||
    sessionStorage.getItem(recoveryStorageKey) === 'true';

function showPasswordUpdateForm() {
    isRecoveryFlow = true;
    sessionStorage.setItem(recoveryStorageKey, 'true');
    loginForm?.classList.add('hidden');
    resetSection?.classList.add('hidden');
    passwordUpdateSection?.classList.remove('hidden');
    window.history.replaceState(
        window.history.state,
        document.title,
        `${window.location.pathname}${window.location.search}`,
    );
}

async function redirectIfAdminSessionExists() {
    if (isRecoveryFlow) return;

    const { data, error } = await closetxSupabase.auth.getSession();
    if (error) {
        showMessage(error.message);
        return;
    }

    if (!data.session) return;

    try {
        if (await isClosetXAdmin()) {
            window.location.replace('dashboard.html');
        } else {
            const { error: signOutError } = await closetxSupabase.auth.signOut();
            if (signOutError) throw signOutError;
        }
    } catch (authError) {
        console.error('Could not verify admin access:', authError);
        showMessage('Unable to verify admin access. Please try again.');
    }
}

function showMessage(message, type = 'error') {
    const errorAlert = document.getElementById('errorAlert');
    const errorMessage = document.getElementById('errorMessage');
    if (!errorAlert || !errorMessage) return;

    errorMessage.textContent = message;
    errorAlert.classList.remove('hidden');
    errorAlert.classList.toggle('bg-green-500/10', type === 'success');
    errorAlert.classList.toggle('border-green-500/30', type === 'success');
    errorAlert.classList.toggle('bg-red-500/10', type === 'error');
    errorAlert.classList.toggle('border-red-500/30', type === 'error');
}

const loginForm = document.getElementById('loginForm');
const resetSection = document.getElementById('resetSection');
const resetForm = document.getElementById('resetForm');
const passwordUpdateSection = document.getElementById('passwordUpdateSection');
const passwordUpdateForm = document.getElementById('passwordUpdateForm');
const forgotPasswordLink = document.getElementById('forgotPasswordLink');
const backToLoginBtn = document.getElementById('backToLoginBtn');

if (loginForm) {
    closetxSupabaseReady
        .then(async () => {
            closetxSupabase.auth.onAuthStateChange((event, session) => {
                if (event === 'PASSWORD_RECOVERY' && session) {
                    showPasswordUpdateForm();
                }
            });

            if (isRecoveryFlow) {
                const { data, error } = await closetxSupabase.auth.getSession();
                if (error) throw error;
                if (data.session) {
                    showPasswordUpdateForm();
                } else {
                    showMessage('This password reset link is invalid or has expired. Request a new one.');
                }
                return;
            }

            await redirectIfAdminSessionExists();
        })
        .catch((error) => showMessage(error.message || 'Could not connect to ClosetX.'));

    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();

        const email = document.getElementById('email').value.trim();
        const password = document.getElementById('password').value;
        const errorAlert = document.getElementById('errorAlert');
        const loginBtn = document.getElementById('loginBtn');
        const loginBtnText = document.getElementById('loginBtnText');
        const loginSpinner = document.getElementById('loginSpinner');
        const loginArrow = document.getElementById('loginArrow');

        errorAlert.classList.add('hidden');
        loginBtnText.textContent = 'Signing in...';
        loginSpinner.classList.remove('hidden');
        loginArrow.classList.add('hidden');
        loginBtn.disabled = true;

        try {
            await closetxSupabaseReady;
            const { error } = await closetxSupabase.auth.signInWithPassword({
                email,
                password,
            });
            if (error) throw error;

            if (!(await isClosetXAdmin())) {
                const { error: signOutError } = await closetxSupabase.auth.signOut({ scope: 'global' });
                if (signOutError) throw signOutError;
                throw new Error('Access denied. An administrator must grant your account access.');
            }

            window.location.replace('dashboard.html');
        } catch (error) {
            showMessage(error.message || 'Unable to sign in.');
            loginBtnText.textContent = 'Sign In';
            loginSpinner.classList.add('hidden');
            loginArrow.classList.remove('hidden');
            loginBtn.disabled = false;
        }
    });
}

if (forgotPasswordLink && resetSection && loginForm) {
    forgotPasswordLink.addEventListener('click', () => {
        loginForm.classList.add('hidden');
        resetSection.classList.remove('hidden');
    });
}

if (backToLoginBtn && resetSection && loginForm) {
    backToLoginBtn.addEventListener('click', () => {
        resetSection.classList.add('hidden');
        loginForm.classList.remove('hidden');
    });
}

async function sendResetEmail(email) {
    await closetxSupabaseReady;
    const { error } = await closetxSupabase.auth.resetPasswordForEmail(email, {
        redirectTo: recoveryRedirectUrl,
    });
    if (error) throw error;
}

if (resetForm) {
    resetForm.addEventListener('submit', async (event) => {
        event.preventDefault();

        const email = document.getElementById('resetEmail').value.trim();
        const resetBtn = document.getElementById('resetBtn');
        const resetBtnText = document.getElementById('resetBtnText');
        const resetSpinner = document.getElementById('resetSpinner');

        resetBtnText.textContent = 'Sending...';
        resetSpinner.classList.remove('hidden');
        resetBtn.disabled = true;

        try {
            await sendResetEmail(email);
            showMessage('If that email belongs to an account, a reset link has been sent.', 'success');
        } catch (error) {
            showMessage(error.message || 'Unable to send the reset link.');
        } finally {
            resetBtnText.textContent = 'Send Reset Link';
            resetSpinner.classList.add('hidden');
            resetBtn.disabled = false;
        }
    });
}

if (passwordUpdateForm) {
    passwordUpdateForm.addEventListener('submit', async (event) => {
        event.preventDefault();

        const password = document.getElementById('newPassword').value;
        const confirmPassword = document.getElementById('confirmNewPassword').value;
        const updatePasswordBtn = document.getElementById('updatePasswordBtn');

        if (password !== confirmPassword) {
            showMessage('The passwords do not match.');
            return;
        }

        updatePasswordBtn.disabled = true;
        updatePasswordBtn.textContent = 'Updating password...';

        try {
            await closetxSupabaseReady;
            const { error } = await closetxSupabase.auth.updateUser({ password });
            if (error) throw error;

            const { error: signOutError } = await closetxSupabase.auth.signOut();
            sessionStorage.removeItem(recoveryStorageKey);
            isRecoveryFlow = false;
            passwordUpdateForm.reset();
            passwordUpdateSection.classList.add('hidden');
            loginForm.classList.remove('hidden');
            showMessage(
                signOutError
                    ? 'Your password was updated, but the recovery session could not be signed out. Close this tab, then sign in with your new password.'
                    : 'Your password was updated. You can now sign in with your new password.',
                signOutError ? 'error' : 'success',
            );
        } catch (error) {
            showMessage(error.message || 'Unable to update your password.');
        } finally {
            updatePasswordBtn.disabled = false;
            updatePasswordBtn.textContent = 'Update Password';
        }
    });
}
