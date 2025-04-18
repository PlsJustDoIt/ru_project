import User from '../../models/user.js';

const TEXT_MIN_LENGTH = 3;
const TEXT_MAX_LENGTH = 32;

// Fonction utilitaire pour calculer la distance de Levenshtein
const levenshteinDistance = (str1: string, str2: string): number => {
    const m = str1.length;
    const n = str2.length;
    const dp: number[][] = Array(m + 1).fill(null).map(() => Array(n + 1).fill(0));

    for (let i = 0; i <= m; i++) {
        dp[i][0] = i;
    }
    for (let j = 0; j <= n; j++) {
        dp[0][j] = j;
    }

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (str1[i - 1] === str2[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1];
            } else {
                dp[i][j] = Math.min(
                    dp[i - 1][j - 1] + 1,
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                );
            }
        }
    }

    return dp[m][n];
};

const validateUsername = (username: string) => {
    username = username.trim();
    if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
        return false;
    }
    return true;
};

const getUserByUsername = async (username: string) => {
    return await User.findOne({ username });
};

const getUserById = async (userId: string, select?: string) => {
    if (!select) {
        return await User.findById(userId);
    }
    return await User.findById(userId).select(select);
};

export { levenshteinDistance, validateUsername, getUserByUsername, getUserById };
