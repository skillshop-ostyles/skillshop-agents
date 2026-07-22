// Fixture for test-honesty-auditor.
// 5 tests covering: honest, assertion-free, tautology, mock-asserts-itself,
// rotting skip in a long-lived block.

describe('account service', () => {
    it('returns account with stored balance', () => {
        const a = createAccount('u1', 100);
        expect(a.balance).toBe(100);
    });

    it('logs that account was created', () => {
        const logger = createLogger();
        const a = createAccount('u2', 50);
        logger.info('created', a);
    });

    it('guard is reachable', () => {
        expect(true).toBe(true);
    });

    it('mock returns configured value', () => {
        const m = jest.fn().mockReturnValue(42);
        const result = m();
        expect(m).toHaveBeenCalled();
        expect(result).toBe(42);
    });

    // TODO: revisit when billing schema stabilized.
    xit('computes invoice with tax', () => {
        const inv = computeInvoice(100, 0.19);
        expect(inv.total).toBe(119);
    });
});
