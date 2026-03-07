import { getUserByUsername, levenshteinDistance, TEXT_MAX_LENGTH, validateUsername } from './user.service.js';
import logger from '../../utils/logger.js';
import User from '../../models/user.js';
jest.mock('../../models/user.js');

describe('user service tests', () => {
    beforeAll(() => {
        logger.info = jest.fn(); // Mock logger.info
        logger.error = jest.fn(); // Mock logger.error
    });

    describe('validateUsername', () => {
        it('should return true for valid usernames', () => {
            expect(validateUsername('user')).toBe(true);
            expect(validateUsername('ab')).toBe(false);
            expect(validateUsername('')).toBe(false);
            expect(validateUsername('username123')).toBe(true);
        });

        it('should return false for usernames that are too short or too long', () => {
            expect(validateUsername('ab')).toBe(false);
            expect(validateUsername('a')).toBe(false);
            expect(validateUsername('a'.repeat(TEXT_MAX_LENGTH + 1))).toBe(false);
            expect(validateUsername('a'.repeat(TEXT_MAX_LENGTH))).toBe(true);
        });

        it('should trim whitespace from the username', () => {
            expect(validateUsername('   user   ')).toBe(true);
            expect(validateUsername('   ')).toBe(false);
        });
    });

    describe('levenshteinDistance', () => {
        it('should return 0 when both strings are empty', () => {
            expect(levenshteinDistance('', '')).toBe(0);
        });

        it('should return the length of the string when the other string is empty', () => {
            expect(levenshteinDistance('abc', '')).toBe(3);
            expect(levenshteinDistance('', 'abc')).toBe(3);
        });

        it('should return 0 when both strings are equal', () => {
            expect(levenshteinDistance('abc', 'abc')).toBe(0);
        });

        it('should return the correct distance for simple cases', () => {
            expect(levenshteinDistance('abc', 'abd')).toBe(1);
            expect(levenshteinDistance('abc', 'ac')).toBe(1);
            expect(levenshteinDistance('abc', 'bc')).toBe(1);
        });

        it('should return the correct distance for more complex cases', () => {
            expect(levenshteinDistance('kitten', 'sitting')).toBe(3);
            expect(levenshteinDistance('flaw', 'lawn')).toBe(2);
            expect(levenshteinDistance('intention', 'execution')).toBe(5);
        });

        it('should be case-sensitive', () => {
            expect(levenshteinDistance('abc', 'Abc')).toBe(1);
        });
    });

    describe('getUserByUsername', () => {
        it('should return null for non-existent usernames', async () => {
            (User.findOne as jest.Mock).mockResolvedValue(null); // Simulate a user found
            const user = await getUserByUsername('nonexistentuser');
            expect(user).toBeNull();
        });

        it('should return the user object for existing usernames', async () => {
            const mockUser = { username: 'existinguser', password: 'hashedPassword' };
            (User.findOne as jest.Mock).mockResolvedValue(mockUser); // Simulate a user found
            const user = await getUserByUsername('existinguser');
            expect(user).not.toBeNull();
            expect(user!.username).toBe('existinguser');
        });
    });
});
