/**
 * n8n-install Welcome Page
 * Dynamic rendering of services and credentials from data.json
 */

(function() {
    'use strict';

    // Service metadata - hardcoded info about each service
    const SERVICE_METADATA = {
        'n8n': {
            name: 'n8n',
            description: 'Workflow Automation',
            icon: 'n8n',
            color: 'bg-orange-500',
            category: 'automation'
        },
        'flowise': {
            name: 'Flowise',
            description: 'AI Agent Builder',
            icon: 'FL',
            color: 'bg-blue-500',
            category: 'ai'
        },
        'open-webui': {
            name: 'Open WebUI',
            description: 'ChatGPT-like Interface',
            icon: 'AI',
            color: 'bg-green-500',
            category: 'ai'
        },
        'grafana': {
            name: 'Grafana',
            description: 'Monitoring Dashboard',
            icon: 'GF',
            color: 'bg-orange-600',
            category: 'monitoring'
        },
        'prometheus': {
            name: 'Prometheus',
            description: 'Metrics Collection',
            icon: 'PM',
            color: 'bg-red-500',
            category: 'monitoring'
        },
        'portainer': {
            name: 'Portainer',
            description: 'Docker Management UI',
            icon: 'PT',
            color: 'bg-cyan-500',
            category: 'infra'
        },
        'postgresus': {
            name: 'Postgresus',
            description: 'PostgreSQL Backups & Monitoring',
            icon: 'PG',
            color: 'bg-blue-600',
            category: 'database'
        },
        'langfuse': {
            name: 'Langfuse',
            description: 'AI Observability',
            icon: 'LF',
            color: 'bg-violet-500',
            category: 'ai'
        },
        'supabase': {
            name: 'Supabase',
            description: 'Backend as a Service',
            icon: 'SB',
            color: 'bg-emerald-500',
            category: 'database'
        },
        'dify': {
            name: 'Dify',
            description: 'AI Application Platform',
            icon: 'DF',
            color: 'bg-indigo-500',
            category: 'ai'
        },
        'qdrant': {
            name: 'Qdrant',
            description: 'Vector Database',
            icon: 'QD',
            color: 'bg-purple-500',
            category: 'database'
        },
        'weaviate': {
            name: 'Weaviate',
            description: 'Vector Database',
            icon: 'WV',
            color: 'bg-green-600',
            category: 'database'
        },
        'neo4j': {
            name: 'Neo4j',
            description: 'Graph Database',
            icon: 'N4',
            color: 'bg-blue-700',
            category: 'database'
        },
        'searxng': {
            name: 'SearXNG',
            description: 'Private Metasearch Engine',
            icon: 'SX',
            color: 'bg-teal-500',
            category: 'tools'
        },
        'ragapp': {
            name: 'RAGApp',
            description: 'RAG UI & API',
            icon: 'RA',
            color: 'bg-amber-500',
            category: 'ai'
        },
        'ragflow': {
            name: 'RAGFlow',
            description: 'Document Understanding RAG',
            icon: 'RF',
            color: 'bg-rose-500',
            category: 'ai'
        },
        'lightrag': {
            name: 'LightRAG',
            description: 'Graph-based RAG',
            icon: 'LR',
            color: 'bg-lime-600',
            category: 'ai'
        },
        'letta': {
            name: 'Letta',
            description: 'Agent Server & SDK',
            icon: 'LT',
            color: 'bg-fuchsia-500',
            category: 'ai'
        },
        'comfyui': {
            name: 'ComfyUI',
            description: 'Stable Diffusion UI',
            icon: 'CU',
            color: 'bg-pink-500',
            category: 'ai'
        },
        'libretranslate': {
            name: 'LibreTranslate',
            description: 'Translation API',
            icon: 'TR',
            color: 'bg-sky-500',
            category: 'tools'
        },
        'docling': {
            name: 'Docling',
            description: 'Document Converter',
            icon: 'DL',
            color: 'bg-stone-500',
            category: 'tools'
        },
        'paddleocr': {
            name: 'PaddleOCR',
            description: 'OCR API Server',
            icon: 'OC',
            color: 'bg-yellow-600',
            category: 'tools'
        },
        'postiz': {
            name: 'Postiz',
            description: 'Social Publishing Platform',
            icon: 'PZ',
            color: 'bg-violet-600',
            category: 'tools'
        },
        'waha': {
            name: 'WAHA',
            description: 'WhatsApp HTTP API',
            icon: 'WA',
            color: 'bg-green-700',
            category: 'tools'
        },
        'crawl4ai': {
            name: 'Crawl4AI',
            description: 'Web Crawler for AI',
            icon: 'C4',
            color: 'bg-gray-600',
            category: 'tools'
        },
        'gotenberg': {
            name: 'Gotenberg',
            description: 'PDF Generator API',
            icon: 'GT',
            color: 'bg-red-600',
            category: 'tools'
        },
        'ollama': {
            name: 'Ollama',
            description: 'Local LLM Runner',
            icon: 'OL',
            color: 'bg-gray-700',
            category: 'ai'
        },
        'redis': {
            name: 'Redis (Valkey)',
            description: 'In-Memory Data Store',
            icon: 'RD',
            color: 'bg-red-700',
            category: 'infra'
        },
        'postgres': {
            name: 'PostgreSQL',
            description: 'Relational Database',
            icon: 'PG',
            color: 'bg-blue-800',
            category: 'infra'
        },
        'python-runner': {
            name: 'Python Runner',
            description: 'Custom Python Scripts',
            icon: 'PY',
            color: 'bg-yellow-500',
            category: 'tools'
        },
        'cloudflare-tunnel': {
            name: 'Cloudflare Tunnel',
            description: 'Zero-Trust Network Access',
            icon: 'CF',
            color: 'bg-orange-500',
            category: 'infra'
        }
    };

    // DOM Elements
    const servicesContainer = document.getElementById('services-container');
    const quickstartContainer = document.getElementById('quickstart-container');
    const domainInfo = document.getElementById('domain-info');
    const errorToast = document.getElementById('error-toast');
    const errorMessage = document.getElementById('error-message');

    /**
     * Show error toast
     */
    function showError(message) {
        errorMessage.textContent = message;
        errorToast.classList.remove('hidden');
        setTimeout(() => {
            errorToast.classList.remove('translate-y-20', 'opacity-0');
        }, 10);

        setTimeout(() => {
            errorToast.classList.add('translate-y-20', 'opacity-0');
            setTimeout(() => errorToast.classList.add('hidden'), 300);
        }, 5000);
    }

    /**
     * Create password field with toggle and copy buttons
     */
    function createPasswordField(password) {
        const container = document.createElement('div');
        container.className = 'flex items-center gap-1';

        const passwordSpan = document.createElement('span');
        passwordSpan.className = 'font-mono text-sm select-all';
        passwordSpan.textContent = '*'.repeat(Math.min(password.length, 12));
        passwordSpan.dataset.password = password;
        passwordSpan.dataset.hidden = 'true';

        // Toggle visibility button (eye icon)
        const toggleBtn = document.createElement('button');
        toggleBtn.className = 'p-1 rounded hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500';
        toggleBtn.innerHTML = `
            <svg class="w-4 h-4 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>
        `;
        toggleBtn.title = 'Hold to reveal';

        // Show password on mouse down, hide on mouse up/leave
        const showPassword = () => {
            passwordSpan.textContent = passwordSpan.dataset.password;
            passwordSpan.dataset.hidden = 'false';
        };
        const hidePassword = () => {
            passwordSpan.textContent = '*'.repeat(Math.min(password.length, 12));
            passwordSpan.dataset.hidden = 'true';
        };

        toggleBtn.addEventListener('mousedown', showPassword);
        toggleBtn.addEventListener('mouseup', hidePassword);
        toggleBtn.addEventListener('mouseleave', hidePassword);
        toggleBtn.addEventListener('touchstart', showPassword);
        toggleBtn.addEventListener('touchend', hidePassword);

        // Copy button
        const copyBtn = document.createElement('button');
        copyBtn.className = 'p-1 rounded hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500';
        copyBtn.innerHTML = `
            <svg class="w-4 h-4 text-gray-500 dark:text-gray-400 copy-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <svg class="w-4 h-4 text-green-500 check-icon hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
        `;
        copyBtn.title = 'Copy to clipboard';

        copyBtn.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(password);
                // Show checkmark
                const copyIcon = copyBtn.querySelector('.copy-icon');
                const checkIcon = copyBtn.querySelector('.check-icon');
                copyIcon.classList.add('hidden');
                checkIcon.classList.remove('hidden');
                // Revert after 2 seconds
                setTimeout(() => {
                    copyIcon.classList.remove('hidden');
                    checkIcon.classList.add('hidden');
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
            }
        });

        container.appendChild(passwordSpan);
        container.appendChild(toggleBtn);
        container.appendChild(copyBtn);

        return container;
    }

    /**
     * Render a single service card
     */
    function renderServiceCard(key, serviceData) {
        const metadata = SERVICE_METADATA[key] || {
            name: key,
            description: '',
            icon: key.substring(0, 2).toUpperCase(),
            color: 'bg-slate-500'
        };

        const card = document.createElement('div');
        card.className = 'bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700 p-5 hover:shadow-lg transition-shadow';

        // Build credentials section
        let credentialsHtml = '';
        if (serviceData.credentials) {
            const creds = serviceData.credentials;

            if (creds.note) {
                credentialsHtml = `
                    <div class="mt-4 pt-4 border-t border-gray-100 dark:border-slate-700">
                        <p class="text-sm text-gray-500 dark:text-gray-400 italic">${escapeHtml(creds.note)}</p>
                    </div>
                `;
            } else {
                let fields = [];
                if (creds.username) {
                    fields.push(`
                        <div class="flex justify-between items-center">
                            <span class="text-gray-500 dark:text-gray-400 text-sm">Username:</span>
                            <span class="font-mono text-sm select-all">${escapeHtml(creds.username)}</span>
                        </div>
                    `);
                }
                if (creds.password) {
                    fields.push(`
                        <div class="flex justify-between items-center" id="pwd-${key}">
                            <span class="text-gray-500 dark:text-gray-400 text-sm">Password:</span>
                        </div>
                    `);
                }
                if (creds.api_key) {
                    fields.push(`
                        <div class="flex justify-between items-center" id="api-${key}">
                            <span class="text-gray-500 dark:text-gray-400 text-sm">API Key:</span>
                        </div>
                    `);
                }

                if (fields.length > 0) {
                    credentialsHtml = `
                        <div class="mt-4 pt-4 border-t border-gray-100 dark:border-slate-700 space-y-2">
                            ${fields.join('')}
                        </div>
                    `;
                }
            }
        }

        // Build extra info section (internal URLs, etc.)
        let extraHtml = '';
        if (serviceData.extra) {
            const extraItems = [];
            const extra = serviceData.extra;

            if (extra.internal_api) {
                extraItems.push(`<span class="text-xs text-gray-400 dark:text-gray-500">Internal: ${escapeHtml(extra.internal_api)}</span>`);
            }
            if (extra.workers) {
                extraItems.push(`<span class="text-xs text-gray-400 dark:text-gray-500">Workers: ${escapeHtml(extra.workers)}</span>`);
            }
            if (extra.recommendation) {
                extraItems.push(`<span class="text-xs text-amber-600 dark:text-amber-400">${escapeHtml(extra.recommendation)}</span>`);
            }

            if (extraItems.length > 0) {
                extraHtml = `<div class="mt-2 flex flex-wrap gap-2">${extraItems.join('')}</div>`;
            }
        }

        card.innerHTML = `
            <div class="flex items-start gap-4">
                <div class="${metadata.color} w-12 h-12 rounded-lg flex items-center justify-center text-white font-bold text-sm flex-shrink-0">
                    ${metadata.icon}
                </div>
                <div class="flex-1 min-w-0">
                    <h3 class="font-semibold text-lg">${escapeHtml(metadata.name)}</h3>
                    <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">${escapeHtml(metadata.description)}</p>
                    ${serviceData.hostname ? `
                        <a href="https://${escapeHtml(serviceData.hostname)}" target="_blank" rel="noopener"
                           class="text-blue-500 hover:text-blue-600 text-sm font-medium inline-flex items-center gap-1 group">
                            ${escapeHtml(serviceData.hostname)}
                            <svg class="w-3 h-3 group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                            </svg>
                        </a>
                    ` : '<span class="text-sm text-gray-400 dark:text-gray-500 italic">Internal service</span>'}
                    ${extraHtml}
                </div>
            </div>
            ${credentialsHtml}
        `;

        // Add password fields after card is created
        if (serviceData.credentials) {
            const creds = serviceData.credentials;

            setTimeout(() => {
                if (creds.password) {
                    const pwdContainer = card.querySelector(`#pwd-${key}`);
                    if (pwdContainer) {
                        pwdContainer.appendChild(createPasswordField(creds.password));
                    }
                }
                if (creds.api_key) {
                    const apiContainer = card.querySelector(`#api-${key}`);
                    if (apiContainer) {
                        apiContainer.appendChild(createPasswordField(creds.api_key));
                    }
                }
            }, 0);
        }

        return card;
    }

    /**
     * Render all services
     */
    function renderServices(services) {
        servicesContainer.innerHTML = '';

        if (!services || Object.keys(services).length === 0) {
            servicesContainer.innerHTML = `
                <div class="col-span-full text-center py-8 text-gray-500 dark:text-gray-400">
                    <p>No services configured. Run the installer to set up services.</p>
                </div>
            `;
            return;
        }

        // Sort services: external first (with hostname), then internal
        const sortedKeys = Object.keys(services).sort((a, b) => {
            const aHasHostname = services[a].hostname ? 1 : 0;
            const bHasHostname = services[b].hostname ? 1 : 0;
            return bHasHostname - aHasHostname;
        });

        sortedKeys.forEach(key => {
            servicesContainer.appendChild(renderServiceCard(key, services[key]));
        });
    }

    /**
     * Render quick start steps
     */
    function renderQuickStart(steps) {
        quickstartContainer.innerHTML = '';

        if (!steps || steps.length === 0) {
            // Default steps if none provided
            steps = [
                { step: 1, title: 'Log into n8n', description: 'Use the email you provided during installation' },
                { step: 2, title: 'Create your first workflow', description: 'Start with a Manual Trigger + HTTP Request nodes' },
                { step: 3, title: 'Explore community workflows', description: 'Check imported workflows for 300+ examples' },
                { step: 4, title: 'Monitor your system', description: 'Use Grafana to track performance' }
            ];
        }

        steps.forEach(item => {
            const stepEl = document.createElement('div');
            stepEl.className = 'flex items-start gap-4 p-4 bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700';

            stepEl.innerHTML = `
                <div class="w-8 h-8 rounded-full bg-green-500 text-white flex items-center justify-center font-bold text-sm flex-shrink-0">
                    ${item.step}
                </div>
                <div>
                    <h4 class="font-semibold">${escapeHtml(item.title)}</h4>
                    <p class="text-sm text-gray-500 dark:text-gray-400">${escapeHtml(item.description)}</p>
                </div>
            `;

            quickstartContainer.appendChild(stepEl);
        });
    }

    /**
     * Escape HTML to prevent XSS
     */
    function escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Load data and render page
     */
    async function init() {
        try {
            const response = await fetch('data.json');

            if (!response.ok) {
                throw new Error(`Failed to load data (${response.status})`);
            }

            const data = await response.json();

            // Update domain info
            if (data.domain) {
                domainInfo.textContent = `Domain: ${data.domain}`;
            }
            if (data.generated_at) {
                const date = new Date(data.generated_at);
                domainInfo.textContent += ` | Generated: ${date.toLocaleString()}`;
            }

            // Render services
            renderServices(data.services);

            // Render quick start
            renderQuickStart(data.quick_start);

        } catch (error) {
            console.error('Error loading data:', error);

            // Show error in UI
            servicesContainer.innerHTML = `
                <div class="col-span-full bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-6 text-center">
                    <svg class="w-12 h-12 mx-auto text-red-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                    </svg>
                    <h3 class="font-semibold text-red-700 dark:text-red-400 mb-2">Unable to load service data</h3>
                    <p class="text-sm text-red-600 dark:text-red-300">Make sure the installation completed successfully and data.json was generated.</p>
                </div>
            `;

            // Still render default quick start
            renderQuickStart(null);
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
