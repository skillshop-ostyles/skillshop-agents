function nextBillingDate(dateStr) {
  // Bug: setMonth auf einem Monatsletzten kann in den uebernaechsten Monat rollen,
  // wenn der Zielmonat weniger Tage hat als der Ausgangstag (z.B. 31. Jan + 1 Monat
  // -> "31. Feb" existiert nicht -> JS normalisiert auf 2. Maerz statt 29. Feb).
  const date = new Date(dateStr);
  date.setMonth(date.getMonth() + 1);
  return date.toISOString().slice(0, 10);
}

module.exports = { nextBillingDate };
