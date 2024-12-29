export default {
    meta: {
        type: 'problem',
        docs: {
            description: 'Ensure res.json receives a JSON-compatible object',
            category: 'Possible Errors',
        },
        schema: [], // Pas de configuration
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
                    if (
                        arg
                        && (arg.type !== 'ObjectExpression')
                    ) {
                        context.report({
                            node,
                            message: 'res.json should only be used with JSON-compatible objects.',
                        });
                    }
                }
            },
        };
    },
};
