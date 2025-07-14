// Plik index.js - TYLKO DO CELÓW TESTOWYCH

// Importujemy bibliotekę tak, jak ostatnio
const aiplatform = require('@google-cloud/aiplatform');

// Wypisujemy na konsolę DOKŁADNIE to, co zaimportowaliśmy
console.log('--- Rozpoczynam inspekcję modułu aiplatform ---');
console.log(aiplatform);
console.log('--- Klucze (właściwości) w obiekcie aiplatform ---');
console.log(Object.keys(aiplatform));
console.log('--- Koniec inspekcji ---');