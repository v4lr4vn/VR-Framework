export const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

export const toDate = (v) => {
    if (v === true) return new Date();
    if (v === null || v === undefined || v === false || v === '') return null;
    if (v instanceof Date) return v;
    if (typeof v === 'number') return new Date(v < 1e11 ? v * 1000 : v);
    if (typeof v === 'string') {
        const m = v.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/);
        if (m) return new Date(+m[3], +m[2] - 1, +m[1]);
        const d = new Date(v);
        return isNaN(d) ? null : d;
    }
    return null;
};

export const dayStart = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

export const sameDay = (a, b) => a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

const pad = (n) => String(n).padStart(2, '0');

export const fmtDate = (d, f = 'DD/MM/YYYY') => {
    if (!d) return '';
    return f.replace(/YYYY|YY|MMMM|MMM|MM|M|DD|D|HH|H|hh|h|mm|A|a/g, (t) => {
        switch (t) {
            case 'YYYY': return String(d.getFullYear());
            case 'YY': return String(d.getFullYear()).slice(-2);
            case 'MMMM': return MONTHS[d.getMonth()];
            case 'MMM': return MONTHS[d.getMonth()].slice(0, 3);
            case 'MM': return pad(d.getMonth() + 1);
            case 'M': return String(d.getMonth() + 1);
            case 'DD': return pad(d.getDate());
            case 'D': return String(d.getDate());
            case 'HH': return pad(d.getHours());
            case 'H': return String(d.getHours());
            case 'hh': return pad(d.getHours() % 12 || 12);
            case 'h': return String(d.getHours() % 12 || 12);
            case 'mm': return pad(d.getMinutes());
            case 'A': return d.getHours() < 12 ? 'AM' : 'PM';
            case 'a': return d.getHours() < 12 ? 'am' : 'pm';
            default: return t;
        }
    });
};

export const grid = (year, month) => {
    const first = new Date(year, month, 1);
    const offset = (first.getDay() + 6) % 7;
    const days = [];
    for (let i = 0; i < 42; i++) days.push(new Date(year, month, 1 - offset + i));
    return days;
};
