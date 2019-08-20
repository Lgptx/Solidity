pragma solidity ^0.4.11;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    address public beneficiary;
    uint public auctionStart;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint public highestBid;

    // Retiradas permitidas por negociações prévias

    mapping(address => uint) pendingReturns;

    event AuctionEnded(address winner, uint highestBid);

    /// Modificadores são um meio conveniente para validas
            /// entradas nas funções. "onlyBefore" é aplicado ao negócio
            /// abaixo:
            /// O novo corpo da função é o modificador do corpo onde "_"
            /// é substituido pelo corpo antigo da função.

    modifier onlyBefore(uint _time) { require(now < _time); _; }
    modifier onlyAfter(uint _time) { require(now > _time); _; }

    function BlindAuction(
        uint _biddingTime,
        uint _revealTime,
        address _beneficiary
    ) {
        beneficiary = _beneficiary;
        auctionStart = now;
        biddingEnd = now + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

            /// Colocar uma negociação "cega" com `_blindedBid` = keccak256(value,
    /// fake, secret).
            /// Os ethers remetidos somente são devolvido se a negociação
            /// for corretamente revelada na fase de revelação de propostas. A negociação
            /// é valida se o valor enviado junto com a negociação é ao menos "value" e
            /// fake não é verdadeiro.
            /// Configurar fake para "true" (verdadeiro) e enviar nao exatamente o valor são
            /// maneiras de esconder a oferta real mas ainda fazer o depósito requerido. O mesmo
            /// endereço pode colocar multiplas ofertas.

    function bid(bytes32 _blindedBid)
        payable
        onlyBefore(biddingEnd)
    {
        bids[msg.sender].push(Bid({
            blindedBid: _blindedBid,
            deposit: msg.value
        }));
    }

            /// Revelar as ofertas "cegas". Você ira restituir para todos
            /// ofertas inválidas corretamente cegas e para todas as ofertas
            /// exceto para a mais alta de todas.

    function reveal(
        uint[] _values,
        bool[] _fake,
        bytes32[] _secret
    )
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        uint length = bids[msg.sender].length;
        require(_values.length == length);
        require(_fake.length == length);
        require(_secret.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            var bid = bids[msg.sender][i];
            var (value, fake, secret) =
                    (_values[i], _fake[i], _secret[i]);
            if (bid.blindedBid != keccak256(value, fake, secret)) {
                // Oferta não foi realmente revelada.
                                    // Não faça o depósito de restituição.

                continue;
            }
            refund += bid.deposit;
            if (!fake && bid.deposit >= value) {
                if (placeBid(msg.sender, value))
                    refund -= value;
            }
            // Torne impossível para o remetente reinvindicar
                            // o mesmo depósito.

            bid.blindedBid = bytes32(0);
        }
        msg.sender.transfer(refund);
    }
            // Esta é uma função "interna" que significa que só
            // pode ser chamada pelo próprio contrato (ou por contra-
            // tos derivados)

    function placeBid(address bidder, uint value) internal
            returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != 0) {
            // Resituir o maior ofertante.

                            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }

            /// Retirar uma oferta que foi superada.

    function withdraw() {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
                            // É importante colocar em zero para que o receptor
                            // possa chamar essa função novamente como parte do recebimento
                            // da chamada antes de "send" retornar (veja o comentário acima sobre condições -->
                            // efeitos --> interações).


            pendingReturns[msg.sender] = 0;

            msg.sender.transfer(amount);
        }
    }

    /// Fim do leilão e envio da maior proposta
            /// para o beneficiário.

    function auctionEnd()
        onlyAfter(revealEnd)
    {
        require(!ended);
        AuctionEnded(highestBidder, highestBid);
        ended = true;

                    // Enviaremos todo o dinheiro existente, porque
                    // algumas das restiuições podem ter falhado.

        beneficiary.transfer(this.balance);
    }
}