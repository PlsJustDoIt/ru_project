export default {
    meta: {
        type: 'problem',
        docs: {
            description: 'Ensure res.json receives a JSON-compatible object',
            category: 'Possible Errors',
        },
        schema: [],
    },
    create(context) {
        return {
            CallExpression(node) {
                const { callee } = node;
                if (
                    callee.type === 'MemberExpression'
                    && callee.object.name === 'res'
                    && callee.property.name === 'json'
                ) {
                    const [arg] = node.arguments;

                    // Autoriser les objets, tableaux et identifiants (variables)
                    if (
                        arg
                        && arg.type !== 'ObjectExpression' // Objet littéral
                        && arg.type !== 'ArrayExpression' // Tableau littéral
                        && arg.type !== 'Identifier' // Variable
                    ) {
                        context.report({
                            node: arg,
                            message: 'res.json should only be used with JSON-compatible objects or variables.',
                        });
                    }
                }
            },
        };
    },
};
