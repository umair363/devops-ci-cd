document.addEventListener('DOMContentLoaded', () => {
    const addForm       = document.getElementById('add-form');
    const listBtn       = document.getElementById('list-btn');
    const uploadForm    = document.getElementById('upload-form');
    const imageInput    = document.getElementById('image-input');
    const loadImagesBtn = document.getElementById('load-images-btn');
    const recordsBox    = document.getElementById('records-container');
    const imagesBox     = document.getElementById('images-container');
    const statusMsg     = document.getElementById('status-msg');
    const fileLabelText = document.getElementById('file-label-text');

    // Show chosen filename in label
    imageInput.addEventListener('change', () => {
        fileLabelText.textContent = imageInput.files[0]
            ? `📎 ${imageInput.files[0].name}`
            : '📎 Choose Image';
    });

    // ── Add Record ─────────────────────────────────────────────────────────
    addForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const btn = document.getElementById('add-btn');
        btn.textContent = 'Adding...'; btn.disabled = true;

        try {
            const res  = await fetch('/api/add', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    title:       document.getElementById('title').value,
                    description: document.getElementById('description').value
                })
            });
            const data = await res.json();
            if (data.success) { addForm.reset(); fetchRecords(); }
            else alert('Error: ' + (data.error || 'Unknown'));
        } catch (err) { alert('Failed to add record.'); }
        finally { btn.textContent = 'Add Record'; btn.disabled = false; }
    });

    // ── List Records ───────────────────────────────────────────────────────
    listBtn.addEventListener('click', fetchRecords);

    async function fetchRecords() {
        listBtn.textContent = 'Loading...';
        try {
            const rows = await (await fetch('/api/list')).json();
            recordsBox.innerHTML = '';
            if (!rows.length) {
                recordsBox.innerHTML = '<p class="empty-state">No records yet.</p>';
                return;
            }
            rows.forEach(r => {
                const el = document.createElement('div');
                el.className = 'record-item';
                el.innerHTML = `
                    <h3>${esc(r.title)}</h3>
                    <p>${esc(r.description)}</p>
                    <small>${new Date(r.created_at).toLocaleString()}</small>`;
                recordsBox.appendChild(el);
            });
        } catch { recordsBox.innerHTML = '<p class="empty-state">Failed to load.</p>'; }
        finally { listBtn.textContent = 'List Records'; }
    }

    // ── Upload Image → S3 ──────────────────────────────────────────────────
    uploadForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const btn = document.getElementById('upload-btn');
        if (!imageInput.files[0]) return alert('Please choose a file first.');

        btn.textContent = 'Uploading...'; btn.disabled = true;
        showStatus('Uploading to S3...', 'info');

        const formData = new FormData();
        formData.append('image', imageInput.files[0]);

        try {
            const res  = await fetch('/api/upload', { method: 'POST', body: formData });
            const data = await res.json();
            if (data.success) {
                showStatus(`✅ Uploaded: ${data.key}`, 'success');
                uploadForm.reset();
                fileLabelText.textContent = '📎 Choose Image';
                // Auto-refresh gallery after upload
                fetchImages();
            } else {
                showStatus('❌ Upload failed: ' + data.error, 'error');
            }
        } catch (err) { showStatus('❌ Upload failed.', 'error'); }
        finally { btn.textContent = 'Upload to S3'; btn.disabled = false; }
    });

    // ── Load S3 Images ─────────────────────────────────────────────────────
    loadImagesBtn.addEventListener('click', fetchImages);

    async function fetchImages() {
        loadImagesBtn.textContent = 'Fetching...';
        loadImagesBtn.disabled = true;
        try {
            const imgs = await (await fetch('/api/images')).json();
            imagesBox.innerHTML = '';
            if (!imgs.length) {
                imagesBox.innerHTML = '<p class="empty-state">No images in S3 bucket yet.</p>';
                return;
            }
            imgs.forEach(img => {
                const el = document.createElement('div');
                el.className = 'gallery-item';
                el.innerHTML = `
                    <img src="${img.url}" alt="${esc(img.key)}" loading="lazy">
                    <div class="gallery-item-overlay"><p>${esc(img.key)}</p></div>`;
                imagesBox.appendChild(el);
            });
        } catch { imagesBox.innerHTML = '<p class="empty-state">Failed to fetch images.</p>'; }
        finally { loadImagesBtn.textContent = 'Load S3 Images'; loadImagesBtn.disabled = false; }
    }

    function showStatus(msg, type) {
        statusMsg.textContent = msg;
        statusMsg.className = `status-msg ${type}`;
        if (type === 'success') setTimeout(() => { statusMsg.textContent = ''; statusMsg.className = ''; }, 4000);
    }

    function esc(s) {
        if (!s) return '';
        return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
                .replace(/"/g,'&quot;').replace(/'/g,'&#039;');
    }
});
