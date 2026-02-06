const API_BASE = "/api";

const shortenForm = document.getElementById("shortenForm");
const statsForm = document.getElementById("statsForm");
const shortenResult = document.getElementById("shortenResult");
const statsResult = document.getElementById("statsResult");
const healthBadge = document.getElementById("healthBadge");
const codeInput = document.getElementById("codeInput");

function showError(container, message) {
  container.classList.remove("hidden");
  container.textContent = message;
  container.style.borderColor = "#fecaca";
  container.style.color = "#b91c1c";
}

function showSuccess(container, html) {
  container.classList.remove("hidden");
  container.innerHTML = html;
  container.style.borderColor = "#cbd5e1";
  container.style.color = "#0f172a";
}

async function checkHealth() {
  try {
    const response = await fetch(`${API_BASE}/health`);
    if (!response.ok) {
      throw new Error(`status ${response.status}`);
    }
    const status = await response.text();
    healthBadge.textContent = `API: ${status}`;
    healthBadge.className = "health health-ok";
  } catch (err) {
    healthBadge.textContent = "API: indisponivel";
    healthBadge.className = "health health-bad";
  }
}

shortenForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const url = document.getElementById("urlInput").value.trim();
  if (!url) {
    showError(shortenResult, "Informe uma URL valida.");
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/shorten`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url }),
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(body || `status ${response.status}`);
    }
    const data = await response.json();
    const shortURL = `${window.location.origin}/r/${data.short}`;
    showSuccess(
      shortenResult,
      `Link curto: <a href="${shortURL}" target="_blank" rel="noreferrer">${shortURL}</a>
       <button id="copyBtn" type="button">Copiar</button>`
    );
    codeInput.value = data.short;
    const copyBtn = document.getElementById("copyBtn");
    if (copyBtn) {
      copyBtn.addEventListener("click", async () => {
        await navigator.clipboard.writeText(shortURL);
        copyBtn.textContent = "Copiado";
      });
    }
  } catch (err) {
    showError(shortenResult, `Falha ao encurtar: ${err.message}`);
  }
});

statsForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const code = codeInput.value.trim();
  if (!code) {
    showError(statsResult, "Informe um codigo curto.");
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/stats/${encodeURIComponent(code)}`);
    if (!response.ok) {
      const body = await response.text();
      throw new Error(body || `status ${response.status}`);
    }
    const data = await response.json();
    showSuccess(statsResult, JSON.stringify(data, null, 2));
  } catch (err) {
    showError(statsResult, `Falha ao buscar stats: ${err.message}`);
  }
});

checkHealth();
setInterval(checkHealth, 10000);
