pragma solidity ^0.4.11;

contract SimpleAuction {
    // Parâmetros do leilão. Tempos são dados em "Unix timestamps" absolutos (segundos desde 01-01-1970)
    // ou períodos de tempo em segundos.

    address public beneficiary;
    uint public auctionStart;
    uint public biddingTime;

    // Estado do leilão corrente.

    address public highestBidder;
    uint public highestBid;

    // Permitidas retiradas de propostas prévias
    mapping(address => uint) pendingReturns;

    // Colocar em "true" no final, desabilitando qualquer mudança
    bool ended;

    // Eventos que serão ativados com as mudanças.

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    // A seguir vem o assim chamado "natspec comment"
    // reconhecível por três barras.
    // Será mostrado quando o usuário é requisitado para
    // confirmar a transação.

    /// Criar um leilão simples com "_biddingTime" segundos,
    /// período de proposta em nome do endereço de beneficiário
    /// "_beneficiary".
    function SimpleAuction(
        uint _biddingTime,
        address _beneficiary
    ) {
        beneficiary = _beneficiary;
        auctionStart = now;
        biddingTime = _biddingTime;
    }

    /// Proposta no leilão com o valor enviado
    /// junto com esta transação.
    /// O valor somente será devolvido se a pro-
    /// posta não for vencedora.

    function bid() payable {
        // Não necessita de argumentos, toda
        // informação faz já parte da transação.
        // A "keyword payable" é requerida para
        // a função estar habilitada a receber Ethers.

        // Reverte a chamada se o período de proposta
        // for encerrado.
        require(now <= (auctionStart + biddingTime));

        // Se a proposta não for a mais alta, enviar o
        // dinheiro de volta

        require(msg.value > highestBid);

        if (highestBidder != 0) {
            // Restituir o dinheiro simplesmente udando
            // " highestBidder.send(highestBid)" é um risco de
            // segurança porque poderia ter executado um contrato
            // não confiável.
            // É sempre mais seguro deixar os destinatários das restiuições
            // resgatar seus valores por eles mesmos.
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        HighestBidIncreased(msg.sender, msg.value);
    }

    /// Restituir uma proposta que foi superada.
    function withdraw() returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // É importante colocar esta variável em zero para que o destinatário
            // possa chamar esta função novamente como parte da chamada recebida
            // antes de "send" retornar.
            pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // Não necessário chamar aqui, somente dar um reset no valor devido.
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// Fim do leilão e envio da proposta mais alta
    /// para o beneficiário.
    function auctionEnd() {
        // É uma boa diretriz estruturar as função que interagem
        // com outros contratos (isto é, elas chamam funções para enviar Ethers)
        // em três fases:
        // 1. verificar condições;
        // 2. realizar ações (condições potenciais de mudança);
        // 3. interagir com outros contratos.
        // Se essas fases forem misturadas, o outro contrato pode
        // chamar de volta dentro do corrente contrato e modificar o estado ou
        // efeito de causa (pagamento de ethers) a ser realizado multiplas vezes.
        // Se as funções chamadas internamente incluiem interação com contratos
        // externos, eles também tem que considerar interações com estes.
        // 1. Condições

        require(now >= (auctionStart + biddingTime)); // leilão não encerrado ainda
        require(!ended); // função já foi chamada

        // 2. Efeitos
        ended = true;
        AuctionEnded(highestBidder, highestBid);

        // 3. Interação
        beneficiary.transfer(highestBid);
    }
}