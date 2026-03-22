const container = document.getElementById('upload-container');
const statusDiv = document.getElementById('status');
const cancelBtn = document.getElementById('cancel-btn');

function closeNUI(url = null) {
    container.classList.add('hidden');
    statusDiv.classList.add('hidden');
    
    fetch(`https://${GetParentResourceName()}/nebula_imghost:onComplete`, {
        method: 'POST',
        body: JSON.stringify({ url: url })
    });
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'openUploader') {
        container.classList.remove('hidden');
        statusDiv.classList.add('hidden');
    }
});

// ESCUCHAMOS EL "PEGAR" (Ctrl+V)
document.addEventListener('paste', async (event) => {
    if (container.classList.contains('hidden')) return;

    const items = (event.clipboardData || event.originalEvent.clipboardData).items;
    
    for (let item of items) {
        if (item.kind === 'file' && item.type.startsWith('image/')) {
            const blob = item.getAsFile();
            if (!blob) return;

            statusDiv.classList.remove('hidden');

            // Cargar la imagen en memoria para comprimirla
            const img = new Image();
            img.onload = function() {
                // Creamos un lienzo invisible para redimensionar la foto
                const canvas = document.createElement('canvas');
                const MAX_SIZE = 512; // Tamaño máximo para no saturar la base de datos
                let width = img.width;
                let height = img.height;

                // Calculamos las nuevas medidas manteniendo la proporción
                if (width > height) {
                    if (width > MAX_SIZE) {
                        height *= MAX_SIZE / width;
                        width = MAX_SIZE;
                    }
                } else {
                    if (height > MAX_SIZE) {
                        width *= MAX_SIZE / height;
                        height = MAX_SIZE;
                    }
                }

                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, width, height);

                // MAGIA: Convertimos la imagen a código de texto (Base64) en formato WebP (muy ligero)
                const base64Data = canvas.toDataURL('image/webp', 0.8);
                
                // Enviamos ese código gigante de texto a Lua
                console.log("Imagen comprimida y convertida a código interno.");
                closeNUI(base64Data);
            }
            img.src = URL.createObjectURL(blob);
        }
    }
});

cancelBtn.addEventListener('click', () => { closeNUI(null); });
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !container.classList.contains('hidden')) { closeNUI(null); }
});