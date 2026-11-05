const escape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const TAGS = /&lt;(\/?)(b|strong|i|em|u|s|small|br|code)\s*\/?&gt;/gi;

const INPUTS = { INPUT_CONTEXT: 'E', INPUT_PICKUP: 'E', INPUT_DETONATE: 'G', INPUT_ENTER: 'F', INPUT_COVER: 'Q', INPUT_RELOAD: 'R', INPUT_FRONTEND_ACCEPT: 'ENTER', INPUT_FRONTEND_CANCEL: 'ESC', INPUT_JUMP: 'SPACE', INPUT_SPRINT: 'SHIFT', INPUT_DUCK: 'CTRL', INPUT_ATTACK: 'LMB', INPUT_AIM: 'RMB' };

const inline = (raw) => {
    let s = escape(raw);
    s = s.replace(/~(INPUT_[A-Z_]+)~/g, (_, k) => `[${INPUTS[k] || 'E'}]`);
    s = s.replace(/~[a-zA-Z]~/g, '').replace(/~h~/g, '');
    const codes = [];
    s = s.replace(/`([^`]+)`/g, (_, c) => {
        codes.push(c);
        return `\u0000${codes.length - 1}\u0000`;
    });
    s = s.replace(TAGS, (_, slash, tag) => (tag.toLowerCase() === 'br' ? '<br>' : `<${slash}${tag.toLowerCase()}>`));
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<span class="link">$1</span>');
    s = s.replace(/\[([A-Za-z0-9+\-]{1,10}|[A-Za-z]{1,6} ?\+ ?[A-Za-z0-9]{1,6})\]/g, '<kbd>$1</kbd>');
    s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/__(.+?)__/g, '<strong>$1</strong>');
    s = s.replace(/(^|[^*])\*(?!\s)(.+?)\*(?!\*)/g, '$1<em>$2</em>').replace(/(^|[\s(])_(?!\s)(.+?)_(?=[\s.,!?)]|$)/g, '$1<em>$2</em>');
    s = s.replace(/~~(.+?)~~/g, '<s>$1</s>');
    s = s.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${codes[Number(i)]}</code>`);
    return s;
};

export const md = (text) => {
    if (text === null || text === undefined) return '';
    const src = String(text).replace(/\r\n?/g, '\n').replace(/\\n/g, '\n');
    const lines = src.split('\n');
    const out = [];
    let para = [];
    let list = null;
    const flushPara = () => {
        if (para.length) out.push(`<p>${para.join('')}</p>`);
        para = [];
    };
    const flushList = () => {
        if (list) out.push(`<${list.tag}>${list.items.map((i) => `<li>${i}</li>`).join('')}</${list.tag}>`);
        list = null;
    };
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trim();
        if (!trimmed) {
            flushPara();
            flushList();
            continue;
        }
        let m;
        if (/^(-{3,}|\*{3,})$/.test(trimmed)) {
            flushPara();
            flushList();
            out.push('<hr>');
        } else if ((m = trimmed.match(/^(#{1,3})\s+(.*)$/))) {
            flushPara();
            flushList();
            out.push(`<h${m[1].length}>${inline(m[2])}</h${m[1].length}>`);
        } else if ((m = trimmed.match(/^[-*+]\s+(.*)$/)) || (m = trimmed.match(/^\d+[.)]\s+(.*)$/))) {
            flushPara();
            const tag = /^\d/.test(trimmed) ? 'ol' : 'ul';
            if (!list || list.tag !== tag) {
                flushList();
                list = { tag, items: [] };
            }
            list.items.push(inline(m[1]));
        } else {
            flushList();
            const hard = /\s{2,}$/.test(line) || line.endsWith('\\');
            if (para.length && !para[para.length - 1].endsWith('<br>')) para.push(' ');
            para.push(inline(trimmed.replace(/\\$/, '')) + (hard ? '<br>' : ''));
        }
    }
    flushPara();
    flushList();
    return out.join('');
};

export const plain = (text) => {
    if (text === null || text === undefined) return '';
    return String(text).replace(/~[a-zA-Z]~/g, '').replace(/<[^>]*>/g, '').replace(/\*\*|__|`/g, '');
};
