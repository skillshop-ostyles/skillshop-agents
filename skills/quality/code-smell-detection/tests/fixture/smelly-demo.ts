// === 1. LONG METHOD (>30 executable lines) ===
function processOrder(order: any, config: any, user: any, inventory: any, payment: any): boolean {
    let result = false;
    let status = "pending";
    let total = 0;
    let discount = 0;
    let tax = 0;
    let shipping = 0;
    let items = order.items || [];
    let valid = true;
    for (let i = 0; i < items.length; i++) {
        let item = items[i];
        if (!item.sku) { valid = false; break; }
        let inv = inventory.find(item.sku);
        if (!inv || inv.stock < item.qty) { valid = false; break; }
        let price = inv.price;
        if (item.qty > 10) { price = price * 0.9; }
        total += price * item.qty;
        let weight = item.weight || 1;
        shipping += weight * 1.5;
    }
    if (!valid) { return false; }
    if (user.tier === "gold") { discount = total * 0.15; }
    else if (user.tier === "silver") { discount = total * 0.1; }
    else if (user.tier === "bronze") { discount = total * 0.05; }
    total = total - discount;
    tax = total * config.taxRate || 0.07;
    shipping = shipping > 50 ? 0 : shipping;
    let grandTotal = total + tax + shipping;
    let chargeResult = payment.charge(user, grandTotal);
    if (!chargeResult.success) { return false; }
    let txId = chargeResult.transactionId;
    status = "completed";
    result = true;
    return result;
}

// === 2. DEEP NESTING (>4 levels) ===
function deepNested(data: any): void {
    if (data) {
        if (data.user) {
            if (data.user.profile) {
                if (data.user.profile.address) {
                    if (data.user.profile.address.city) {
                        if (data.user.profile.address.zip) {
                            console.log(data.user.profile.address.city);
                        }
                    }
                }
            }
        }
    }
}

// === 3. GOD CLASS (large, many methods) ===
class MegaManager {
    private state: any;
    private config: any;
    private cache: Map<string, any>;
    private db: any;
    private logger: any;
    private events: any[];
    private metrics: any;
    private workers: any[];
    private queue: any[];
    private flags: any;

    constructor() { this.state = {}; this.cache = new Map(); this.events = []; this.workers = []; this.queue = []; this.flags = {}; }

    init() { /* 4 lines */ let a = 1; let b = 2; let c = 3; console.log("init"); }
    start() { /* 3 lines */ console.log("start"); this.init(); }
    stop() { /* 3 lines */ console.log("stop"); this.flush(); }
    flush() { /* 3 lines */ console.log("flush"); this.cache.clear(); }
    reloadConfig() { /* 2 lines */ this.config = {}; console.log("reload"); }
    connectDb() { /* 2 lines */ this.db = {}; console.log("db"); }
    disconnectDb() { /* 2 lines */ this.db = null; console.log("disconnect"); }
    enqueue(item: any) { /* 2 lines */ this.queue.push(item); }
    dequeue(): any { /* 3 lines */ return this.queue.shift(); }
    processQueue() { /* 4 lines */ let item = this.dequeue(); if (item) { this.work(item); } }
    work(item: any) { /* 2 lines */ console.log("work", item); }
    addWorker(w: any) { /* 2 lines */ this.workers.push(w); }
    removeWorker(w: any) { /* 2 lines */ this.workers = this.workers.filter(x => x !== w); }
    logEvent(e: any) { /* 2 lines */ this.events.push(e); }
    trackMetric(name: string, value: number) { /* 2 lines */ this.metrics[name] = value; }
}

// === 4. MESSAGE CHAIN (a.b.c.d.e) ===
function getCity(user: any): string {
    return user.profile.address.city.name;
}

// Clean references to MegaManager
function useManager(): void {
    const mm = new MegaManager();
    mm.init();
    mm.start();
}
